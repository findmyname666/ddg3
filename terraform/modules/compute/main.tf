locals {
  resource_group_name = split("/", var.resource_group_id)[4]
  key_vault_name      = split("/", var.key_vault_id)[8]

  tags = {
    Environment = var.environment
    Application = var.app_name
  }
}

# Network Interface
resource "azurerm_network_interface" "this" {
  name                = "nic-${var.app_name}-${var.environment}"
  location            = var.location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.public_ip_id
  }

  tags = local.tags
}

# Cloud-init configuration
# The common.sh, bootstrap.sh, and provision.sh scripts are loaded from the scripts directory
# and embedded into cloud-init to ensure they're available immediately when the VM boots
data "template_cloudinit_config" "this" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
      # Only app_name is needed by cloud-init template itself
      app_name = var.app_name

      # Common script (no template variables needed)
      common_script = indent(6, file("${path.module}/scripts/common.sh"))

      # Bootstrap script (runs as root)
      bootstrap_script = indent(6, templatefile("${path.module}/scripts/bootstrap.sh", {
        app_name    = var.app_name
        fqdn        = var.fqdn
        admin_email = var.admin_email
      }))

      # Provision script (runs as ubuntu user)
      provision_script = indent(6, templatefile("${path.module}/scripts/provision.sh", {
        app_name       = var.app_name
        key_vault_name = local.key_vault_name
        fqdn           = var.fqdn
        admin_email    = var.admin_email
        acr_name       = var.acr_name
      }))

      # Docker Compose configuration
      docker_compose_content = indent(6, templatefile("${path.module}/templates/docker-compose.prod.yml.tftpl", {
        app_name         = var.app_name
        fqdn             = var.fqdn
        acr_login_server = var.acr_login_server
        # Container image references
        db_image_name       = var.container_images.db.name
        db_image_tag        = var.container_images.db.tag
        feedback_image_name = var.container_images.feedback.name
        feedback_image_tag  = var.container_images.feedback.tag
        nginx_image_name    = var.container_images.nginx.name
        nginx_image_tag     = var.container_images.nginx.tag
      }))

      # Systemd analysis service
      analysis_service = indent(6, templatefile("${path.module}/templates/analysis.service.tftpl", {
        app_name = var.app_name
      }))

      # Systemd analysis timer
      analysis_timer = indent(6, templatefile("${path.module}/templates/analysis.timer.tftpl", {
        app_name = var.app_name
      }))
    })
  }
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "this" {
  name                = "vm-${var.app_name}-${var.environment}"
  location            = var.location
  resource_group_name = local.resource_group_name
  size                = var.vm_size
  admin_username      = "ubuntu"

  # Assign managed identity to VM for Key Vault access
  identity {
    type         = "UserAssigned"
    identity_ids = [var.vm_identity_id]
  }

  network_interface_ids = [
    azurerm_network_interface.this.id,
  ]

  admin_ssh_key {
    username   = "ubuntu"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = data.template_cloudinit_config.this.rendered

  # Prevent re-provisioning when cloud-init changes (requires VM replacement)
  lifecycle {
    ignore_changes = [custom_data]
  }

  tags = local.tags
}

# Managed Disk for Database Storage
resource "azurerm_managed_disk" "data" {
  name                 = "disk-${var.app_name}-data-${var.environment}"
  location             = var.location
  resource_group_name  = local.resource_group_name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.vm_disk_data_size_gb

  lifecycle {
    prevent_destroy = true
  }

  tags = local.tags
}

# Attach Data Disk to VM
resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  managed_disk_id    = azurerm_managed_disk.data.id
  virtual_machine_id = azurerm_linux_virtual_machine.this.id
  lun                = 0
  caching            = "ReadWrite"
}

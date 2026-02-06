data "azurerm_client_config" "current" {}

locals {
  resource_group_name = split("/", var.resource_group_id)[4]

  tags = {
    Environment = var.environment
    Application = var.app_name
  }
}

# Random suffix for Key Vault name (must be globally unique)
resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Azure Key Vault
resource "azurerm_key_vault" "this" {
  name                        = "kv-${var.app_name}-${var.environment}-${random_string.kv_suffix.result}"
  location                    = var.location
  resource_group_name         = local.resource_group_name
  enabled_for_disk_encryption = true
  enabled_for_deployment      = true
  tenant_id                   = var.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false # Set to true in production
  sku_name                    = "standard"

  # Enable RBAC authorization (recommended over access policies)
  rbac_authorization_enabled = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow" # Restrict to specific IPs/VNets in production
  }

  tags = local.tags
}

# Grant current user/service principal access to manage secrets
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Wait for RBAC permissions to propagate
# Azure RBAC can take 1-5 minutes to propagate
# This prevents 403 errors when creating secrets immediately after role assignment
resource "time_sleep" "wait_for_rbac_propagation" {
  depends_on = [azurerm_role_assignment.kv_admin]

  create_duration = "90s"
}

# Managed Identity for VM to access Key Vault
resource "azurerm_user_assigned_identity" "vm" {
  name                = "id-${var.app_name}-vm-${var.environment}"
  location            = var.location
  resource_group_name = local.resource_group_name

  tags = local.tags
}

# Grant VM identity access to read secrets
resource "azurerm_role_assignment" "vm_secrets_reader" {
  scope                            = azurerm_key_vault.this.id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = azurerm_user_assigned_identity.vm.principal_id
  skip_service_principal_aad_check = true
}

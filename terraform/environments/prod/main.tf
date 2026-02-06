locals {
  # Get all VMs that match vCPU and memory filters from the module
  all_available_vms = module.compute_skus.vms.names.matching

  # Apply regex filter
  filtered_vm_names = [
    for vm_name in local.all_available_vms :
    vm_name
    if can(regex(var.vm_size_filter_regex, vm_name))
  ]

  # Sort for consistent ordering
  sorted_vm_names = sort(local.filtered_vm_names)

  # Get the first matching VM (for auto-selection)
  first_matching_vm = length(local.sorted_vm_names) > 0 ? local.sorted_vm_names[0] : null

  # Use custom domain FQDN if Cloudflare DNS is provisioned,
  # otherwise use Azure's auto-generated FQDN.
  # Handle both old and new Cloudflare provider behavior:
  # - Old behavior: name = "feedduck" (subdomain only)
  # - New behavior (v5.1.0+): name = "feedduck.findmyname.xyz" (full FQDN)
  # I experienced intermittent issues / changes with a new provider version,
  # so I added this fix.
  dns_record_name = length(module.dns) > 0 ? module.dns[0].cname_record_name : ""
  dns_zone_name   = length(module.dns) > 0 ? module.dns[0].zone_name : ""

  # Check if the record name already contains the zone name (new provider behavior)
  # If it does, use it as-is. Otherwise, construct the FQDN.
  app_fqdn = length(module.dns) > 0 ? (
    endswith(local.dns_record_name, local.dns_zone_name) ?
    local.dns_record_name :
    "${local.dns_record_name}.${local.dns_zone_name}"
  ) : module.networking.fqdn
}

# Module: Query Available VM SKUs using open-source module
# This dynamically discovers which VM sizes are available in the region.
module "compute_skus" {
  source  = "Azure-Terraformer/compute-skus/azurerm"
  version = "~> 1.1.2"

  location = var.location

  vm_filter = {
    resources = {
      vcpu = {
        min = var.vm_min_vcpus
        max = var.vm_max_vcpus
      }
      memory_gb = {
        min = var.vm_min_memory_gb
        max = var.vm_max_memory_gb
      }
    }
  }
}

# Module: Resource Group
module "resource_group" {
  source = "../../modules/resource_group"

  app_name    = var.app_name
  environment = var.environment
  location    = var.location
}

# Module: Networking
module "networking" {
  source = "../../modules/networking"

  app_name          = var.app_name
  environment       = var.environment
  location          = var.location
  resource_group_id = module.resource_group.id
  ssh_allowed_ips   = var.ssh_allowed_ips
}

# Cloudflare DNS module - only provisioned when domain_name is specified
module "dns" {
  source = "../../modules/cloudflare"
  count  = var.domain_name != null && var.domain_name != "" ? 1 : 0

  zone_name    = var.domain_name
  record_name  = var.app_name
  cname_target = module.networking.fqdn
  ttl          = 60
  comment      = "FeedDuck production VM - ${var.app_name}/${var.environment}"
}

# Module: Key Vault
module "key_vault" {
  source = "../../modules/key_vault"

  app_name          = var.app_name
  environment       = var.environment
  location          = var.location
  resource_group_id = module.resource_group.id
  tenant_id         = module.resource_group.tenant_id
}

# Module: Secrets
module "secrets" {
  source = "../../modules/secrets"

  app_name            = var.app_name
  key_vault_id        = module.key_vault.id
  asana_token         = var.asana_token
  asana_workspace_gid = var.asana_workspace_gid
  asana_project_gid   = var.asana_project_gid

  # Explicit dependency on the entire key_vault module ensures:
  # 1. On apply: secrets are created AFTER role assignment + RBAC propagation delay
  # 2. On destroy: secrets are deleted BEFORE role assignment (reverse order)
  depends_on = [module.key_vault]
}

# Module: Compute
module "compute" {
  source = "../../modules/compute"

  app_name             = var.app_name
  environment          = var.environment
  location             = var.location
  resource_group_id    = module.resource_group.id
  subnet_id            = module.networking.subnet_id
  public_ip_id         = module.networking.public_ip_id
  vm_size              = local.first_matching_vm
  ssh_public_key       = var.ssh_public_key
  fqdn                 = local.app_fqdn
  admin_email          = var.admin_email
  key_vault_id         = module.key_vault.id
  vm_identity_id       = module.key_vault.vm_identity_id
  vm_disk_data_size_gb = var.vm_disk_data_size_gb

  # Container Registry configuration
  acr_name         = module.container_registry.name
  acr_login_server = module.container_registry.login_server
  container_images = {
    db = {
      name = module.push_images.image_references["db"].name
      tag  = module.push_images.image_references["db"].tag
    }
    feedback = {
      name = module.push_images.image_references["feedback"].name
      tag  = module.push_images.image_references["feedback"].tag
    }
    nginx = {
      name = module.push_images.image_references["nginx"].name
      tag  = module.push_images.image_references["nginx"].tag
    }
  }

  # Ensure secrets, images, and RBAC permissions are ready before VM starts
  depends_on = [module.secrets, module.push_images]
}

# Module: Container Registry
module "container_registry" {
  source = "../../modules/container_registry"

  app_name          = var.app_name
  environment       = var.environment
  location          = var.location
  resource_group_id = module.resource_group.id

  # Grant VM managed identity pull access to ACR
  vm_identity_principal_id = module.key_vault.vm_identity_principal_id
}

# Module: Build and Push Container Images
module "push_images" {
  source = "../../modules/container_image_push"

  acr_name         = module.container_registry.name
  acr_login_server = module.container_registry.login_server

  # Set base directory to repository root
  # path.root = terraform/environments/prod
  # Go up 3 levels: prod -> environments -> terraform -> repo root
  working_directory = "${path.root}/../../../"

  images = {
    db = {
      name            = "${var.app_name}-db"
      tag             = "v0.0.1"
      dockerfile_path = "app/db/Dockerfile"
      context_path    = "app/db"
    }

    feedback = {
      name            = "${var.app_name}-feedback"
      tag             = "v0.0.2"
      dockerfile_path = "app/feedback/Dockerfile"
      context_path    = "app/feedback"
    }

    nginx = {
      name            = "${var.app_name}-nginx"
      tag             = "v0.0.2"
      dockerfile_path = "app/nginx/Dockerfile"
      context_path    = "app/nginx"
    }
  }

  # Ensure ACR is created before building images
  depends_on = [module.container_registry]
}

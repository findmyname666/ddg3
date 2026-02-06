locals {
  resource_group_name = split("/", var.resource_group_id)[4]

  tags = {
    Environment = var.environment
    Application = var.app_name
    ManagedBy   = "Terraform"
  }
}

# Random suffix for ACR name (must be globally unique and alphanumeric only)
resource "random_string" "acr_suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

# Azure Container Registry
resource "azurerm_container_registry" "this" {
  name                = "acr${var.app_name}${var.environment}${random_string.acr_suffix.result}"
  location            = var.location
  resource_group_name = local.resource_group_name
  sku                 = var.sku
  admin_enabled       = false

  # Public network access (set to false for private endpoint only)
  public_network_access_enabled = var.public_network_access_enabled

  # Network rule set (only available for Premium SKU)
  dynamic "network_rule_set" {
    for_each = var.sku == "Premium" && var.network_rule_set != null ? [var.network_rule_set] : []
    content {
      default_action = network_rule_set.value.default_action

      dynamic "ip_rule" {
        for_each = network_rule_set.value.ip_rules
        content {
          action   = "Allow"
          ip_range = ip_rule.value
        }
      }
    }
  }

  tags = local.tags
}

# Grant VM's managed identity pull access to ACR
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = var.vm_identity_principal_id
}

# Optional: Grant VM's managed identity push access to ACR
resource "azurerm_role_assignment" "acr_push" {
  count = var.grant_vm_push_access ? 1 : 0

  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPush"
  principal_id         = var.vm_identity_principal_id
}

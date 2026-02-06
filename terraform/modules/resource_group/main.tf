data "azurerm_client_config" "current" {}

locals {
  tags = {
    Environment = var.environment
    Application = var.app_name
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.app_name}-${var.environment}"
  location = var.location

  tags = local.tags
}

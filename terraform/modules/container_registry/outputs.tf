output "id" {
  value       = azurerm_container_registry.this.id
  description = "ACR resource ID"
}

output "login_server" {
  value       = azurerm_container_registry.this.login_server
  description = "ACR login server URL"
}

output "name" {
  value       = azurerm_container_registry.this.name
  description = "ACR name"
}

output "resource_group_name" {
  value       = local.resource_group_name
  description = "Resource group name where ACR is deployed"
}

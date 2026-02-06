output "id" {
  value       = azurerm_resource_group.this.id
  description = "Resource group ID"
}

output "location" {
  value       = azurerm_resource_group.this.location
  description = "Resource group location"
}

output "name" {
  value       = azurerm_resource_group.this.name
  description = "Resource group name"
}

output "tenant_id" {
  value       = data.azurerm_client_config.current.tenant_id
  description = "Azure AD tenant ID"
}

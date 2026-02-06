output "id" {
  value       = azurerm_key_vault.this.id
  description = "Key Vault ID"
}

output "kv_admin_role_assignment_id" {
  value       = azurerm_role_assignment.kv_admin.id
  description = "Key Vault Administrator role assignment ID (for dependency management)"
}

output "name" {
  value       = azurerm_key_vault.this.name
  description = "Key Vault name"
}

output "uri" {
  value       = azurerm_key_vault.this.vault_uri
  description = "Key Vault URI"
}

output "vm_identity_client_id" {
  value       = azurerm_user_assigned_identity.vm.client_id
  description = "VM managed identity client ID"
}

output "vm_identity_id" {
  value       = azurerm_user_assigned_identity.vm.id
  description = "VM managed identity ID"
}

output "vm_identity_principal_id" {
  value       = azurerm_user_assigned_identity.vm.principal_id
  description = "VM managed identity principal ID"
}

output "vm_secrets_reader_role_assignment_id" {
  value       = azurerm_role_assignment.vm_secrets_reader.id
  description = "VM Secrets Reader role assignment ID (for dependency management)"
}

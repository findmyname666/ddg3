output "asana_secret_name" {
  value       = azurerm_key_vault_secret.asana_credentials.name
  description = "Name of the Key Vault secret containing Asana credentials"
}

output "database_secret_name" {
  value       = azurerm_key_vault_secret.database_passwords.name
  description = "Name of the Key Vault secret containing database passwords"
}

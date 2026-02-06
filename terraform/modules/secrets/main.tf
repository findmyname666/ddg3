# Generate secure random passwords for database users
# These passwords are generated once and stored in Key Vault
# Use lifecycle ignore_changes to prevent regeneration on subsequent runs
ephemeral "random_password" "postgres_password" {
  length  = 32
  special = true
}

ephemeral "random_password" "migration_password" {
  length  = 32
  special = true
}

ephemeral "random_password" "web_app_password" {
  length  = 32
  special = true
}

ephemeral "random_password" "analysis_app_password" {
  length  = 32
  special = true
}

# Store Asana credentials in a separate secret (updated by Terraform)
resource "azurerm_key_vault_secret" "asana_credentials" {
  name         = "${var.app_name}-asana-credentials"
  key_vault_id = var.key_vault_id

  value_wo = jsonencode({
    asana_token         = var.asana_token
    asana_workspace_gid = var.asana_workspace_gid
    asana_project_gid   = var.asana_project_gid
  })

  value_wo_version = 1
}

# Store database passwords in a separate secret (created once, then ignored)
# This prevents regeneration on every Terraform run
# Using value_wo (write-only) to work with ephemeral values
resource "azurerm_key_vault_secret" "database_passwords" {
  name         = "${var.app_name}-database-passwords"
  key_vault_id = var.key_vault_id

  value_wo = jsonencode({
    postgres_password     = ephemeral.random_password.postgres_password.result
    migration_password    = ephemeral.random_password.migration_password.result
    web_app_password      = ephemeral.random_password.web_app_password.result
    analysis_app_password = ephemeral.random_password.analysis_app_password.result
  })

  value_wo_version = 1

  # Ignore changes to prevent regeneration on subsequent runs
  # Passwords are generated on first apply, then persisted in Key Vault
  lifecycle {
    ignore_changes = [value_wo]
  }
}

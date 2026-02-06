# Secrets Module

Terraform module for generating and storing secrets in Azure Key Vault.

## Features

- **Random Password Generation** - Secure 32-character passwords
- **Ephemeral Resources** - Passwords generated using ephemeral resources
- **Lifecycle Management** - Prevents password regeneration on subsequent
  runs
- **Asana Credentials** - Stores API token and workspace/project GIDs
- **Database Passwords** - Stores passwords for all database users

## Secrets Created

### Database Passwords

Module creates only one secret for all database passwords in JSON format:

- `postgres_password` - PostgreSQL superuser password
- `migration_password` - Database migration user password
- `web_app_password` - Web application database user password
- `analysis_app_password` - Analysis application database user password

### Asana Credentials

Module creates only one secret for Asana credentials in JSON format:

- `asana_token` - Asana API token
- `asana_workspace_gid` - Asana workspace GID
- `asana_project_gid` - Asana project GID

## Usage

### Basic Secrets Setup

```hcl
module "secrets" {
  source = "../../modules/secrets"

  app_name            = "feedduck"
  key_vault_id        = module.key_vault.id
  asana_token         = var.asana_token
  asana_workspace_gid = var.asana_workspace_gid
  asana_project_gid   = var.asana_project_gid
}
```

## References

- [Azure Key Vault Secrets](https://learn.microsoft.com/en-us/azure/key-vault/secrets/)

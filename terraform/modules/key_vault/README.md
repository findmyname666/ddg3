# Key Vault Module

Terraform module for creating Azure Key Vault with RBAC authorization and
managed identity for VM access.

## Features

- **RBAC Authorization** - Role-based access control enabled
- **Managed Identity** - User-assigned identity for VM access
- **Automatic Permissions** - Grants Key Vault Administrator to deployer
- **VM Secret Access** - Grants Key Vault Secrets User to VM identity
- **RBAC Propagation Wait** - 90s delay to prevent 403 errors

## Usage

### Basic Key Vault

```hcl
module "key_vault" {
  source = "../../modules/key_vault"

  app_name          = "feedduck"
  environment       = "prod"
  location          = "eastus"
  resource_group_id = module.resource_group.id
  tenant_id         = data.azurerm_client_config.current.tenant_id
}
```

## Security Notes

- Soft delete retention: 7 days
- Purge protection: Disabled (enable in production)
- Network ACLs: Allow all (restrict in production)

## References

- [Azure Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/)
- [Key Vault RBAC](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide)

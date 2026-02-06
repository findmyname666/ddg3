# Resource Group Module

Terraform module for creating Azure Resource Groups.

## Usage

### Basic Resource Group

```hcl
module "resource_group" {
  source = "../../modules/resource_group"

  app_name    = "feedduck"
  environment = "prod"
  location    = "eastus"
}
```

## References

- [Azure Resource Groups](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal)

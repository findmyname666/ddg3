# Networking Module

Terraform module for creating Azure networking resources including VNet,
subnet, public IP, and network security group.

## Features

- **Virtual Network** - 10.0.0.0/16 address space
- **Subnet** - 10.0.1.0/24 address space
- **Static Public IP** - Standard SKU with DNS label
- **Network Security Group** - Preconfigured rules for SSH, HTTP, HTTPS,
  and HTTP/3

## Security Rules

- SSH (port 22) - Restricted to specified IPs
- HTTP (port 80) - Open to all
- HTTPS TCP (port 443) - Open to all
- HTTP/3 UDP (port 443) - Open to all
- Default deny all other inbound traffic

## Usage

### Basic Network Setup

```hcl
module "networking" {
  source = "../../modules/networking"

  app_name         = "feedduck"
  environment      = "prod"
  location         = "eastus"
  resource_group_id = module.resource_group.id
  ssh_allowed_ips  = ["203.0.113.0/24"]
}
```

## References

- [Azure Virtual Network](https://learn.microsoft.com/en-us/azure/virtual-network/)
- [Azure NSG](https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview)

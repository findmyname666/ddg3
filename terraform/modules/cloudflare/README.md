# Cloudflare DNS Module

Terraform module for creating CNAME DNS records in Cloudflare.

## Features

- **CNAME records only** - Points a subdomain to another FQDN
- **Flexible TTL configuration** - Control DNS propagation speed
- **Automatic zone lookup** - No need to manually specify zone ID
- **Custom comments** - Add metadata to DNS records

## Usage

### Basic CNAME Record

```hcl
module "dns" {
  source = "../../modules/cloudflare"

  zone_name    = "example.com"
  record_name  = "app"
  cname_target = "feedduck-vm.eastus.cloudapp.azure.com"
}
# Creates: app.example.com -> feedduck-vm.eastus.cloudapp.azure.com
```

### Production Example (from FeedDuck)

```hcl
module "dns" {
  source = "../../modules/cloudflare"

  zone_name    = var.domain_name
  record_name  = var.app_name
  cname_target = module.networking.fqdn
  ttl          = 60
  comment      = "FeedDuck production VM - ${var.app_name}/${var.environment}"
}
# Creates: feedduck.example.com -> feedduck-vm-prod.eastus.cloudapp.azure.com
```

## Authentication

```bash
export CLOUDFLARE_API_TOKEN="your-token"
```

## References

- [Cloudflare Terraform Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)

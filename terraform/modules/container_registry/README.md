# Azure Container Registry Module

Terraform module for deploying Azure Container Registry (ACR) with support for
multiple repositories and managed identity integration.

## Features

- **Basic SKU by default** (~$5/month) - cost-effective for development
- **Azure AD authentication** - secure authentication using Azure CLI
- **Managed Identity integration** - VM can pull images without credentials
- **Multiple repositories** - track multiple container images using map
  (order-stable)
- **RBAC role assignments** - automatic AcrPull/AcrPush role assignments
- **Globally unique naming** - automatic random suffix generation

## Usage

### Basic Example

```hcl
module "container_registry" {
  source = "../../modules/container_registry"

  app_name          = "feedduck"
  environment       = "prod"
  location          = "westus2"
  resource_group_id = module.resource_group.id

  # Grant VM pull access
  vm_identity_principal_id = module.key_vault.vm_identity_principal_id
}
```

## Local Development Workflow

### 1. Login to ACR

```bash
# Using Azure CLI (requires Azure login)
az acr login --name <acr-name>
```

### 2. Build and Push Images

```bash
# Build image
docker build -t <acr-name>.azurecr.io/<repository-name>:<tag> .

# Push to ACR
docker push <acr-name>.azurecr.io/<repository-name>:<tag>
```

### 3. Pull on VM (using Managed Identity)

The VM automatically has pull access via managed identity:

```bash
# On the VM
az acr login --name <acr-name> --identity
docker pull <acr-name>.azurecr.io/<repository-name>:<tag>
```

### 4. List tags for a repository

```bash
az acr repository show-tags --name <acr-name> --repository <repository-name>
```

## Repository Management

**Note:** ACR repositories are created automatically on first push.

### Cleaning Up Unused Images

Azure Container Registry can quickly fill up with old images.

Delete images older than a specific date:

```bash
# Delete all images older than 30 days
az acr run \
  --cmd "acr purge --filter '.*:.*' --untagged --ago 30d" \
  --registry <acr-name> \
  /dev/null

# Dry run to see what would be deleted (recommended first!)
az acr run \
  --cmd "acr purge --filter '.*:.*' --untagged --ago 30d --dry-run" \
  --registry <acr-name> \
  /dev/null
```

## Troubleshooting

### "unauthorized: authentication required"

- Ensure you're logged in with `az acr login --name <acr-name>`
- Verify your Azure account has appropriate permissions
- Verify managed identity has AcrPull role assignment (for VM)

### "denied: requested access to the resource is denied"

- Check RBAC role assignments (may take 1-5 minutes to propagate)
- Verify VM managed identity has correct permissions
- Check network rules if using Premium SKU

## References

- [Azure Container Registry Documentation](https://learn.microsoft.com/en-us/azure/container-registry/)
- [ACR Pricing](https://azure.microsoft.com/en-us/pricing/details/container-registry/)
- [ACR Best Practices](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-best-practices)

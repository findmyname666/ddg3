# Compute Module

Terraform module for creating Azure Linux VMs with cloud-init provisioning
for containerized applications.

## Features

- **Ubuntu 22.04 LTS** - Latest Canonical image
- **Persistent Data Disk** - Separate managed disk for database storage (survives VM replacement)
- **Cloud-init Provisioning** - Automated VM setup with embedded scripts
- **Managed Identity** - User-assigned identity for Key Vault access
- **Docker Compose** - Containerized application deployment
- **Systemd Services** - Analysis systemd service and timer for scheduled tasks
  (runs every 4 hours)
- **SSH Access** - Public key authentication

## Components

### Network Interface

- Dynamic private IP allocation
- Public IP association
- Environment and application tags

### Virtual Machine

- Standard_B2s (default, configurable)
- Standard SSD OS disk (30GB) - sufficient for OS and application files
- Premium SSD data disk (10GB default, configurable) - mounted at `/mnt/db`
- SSH key authentication
- Custom data with cloud-init

### Data Disk

- **Separate managed disk** for PostgreSQL data
- **Survives VM replacement** - `prevent_destroy` lifecycle policy
- **Mounted at `/mnt/db`** - automatically formatted and mounted on boot
- **Optimized mount options** - `noatime,nodiratime,nofail` for database
  performance
- **PostgreSQL data** stored at `/mnt/db/postgresql`
- **UID 70** ownership (postgres user in Alpine-based containers)

### Cloud-init Configuration

- Common utilities installation
- Docker and Docker Compose setup
- SSL certificate provisioning (Let's Encrypt)
- Azure CLI and Key Vault integration
- Application deployment via Docker Compose
- Systemd timer for analysis tasks

## Usage

### Basic VM Setup

```hcl
module "compute" {
  source = "../../modules/compute"

  app_name             = "feedduck"
  environment          = "prod"
  location             = "eastus"
  resource_group_id    = module.resource_group.id
  subnet_id            = module.networking.subnet_id
  public_ip_id         = module.networking.public_ip_id
  key_vault_id         = module.key_vault.id
  vm_identity_id       = module.key_vault.vm_identity_id
  ssh_public_key       = var.ssh_public_key
  fqdn                 = var.fqdn
  admin_email          = var.admin_email
  acr_name             = module.container_registry.name
  acr_login_server     = module.container_registry.login_server
  vm_disk_data_size_gb = 10  # Optional: data disk size in GB (default: 10)

  container_images = {
    db = {
      name = "feedduck-db"
      tag  = "latest"
    }
    feedback = {
      name = "feedduck-feedback"
      tag  = "latest"
    }
    nginx = {
      name = "feedduck-nginx"
      tag  = "latest"
    }
  }
}
```

## Data Persistence

### VM Restart (Stop/Start)

- **OS disk data**: Preserved
- **Data disk**: Preserved
- **Database data**: Preserved

### VM Replacement (Destroy/Recreate)

- **OS disk**: Deleted
- **Data disk**: Preserved (`prevent_destroy` lifecycle policy)
- **Database data**: Preserved (stored on data disk)

### Expanding Data Disk

```hcl
# Increase disk size (can only grow, never shrink)
vm_disk_data_size_gb = 20  # Changed from 10 to 20
```

After applying, SSH into VM and expand filesystem:

```bash
sudo resize2fs /dev/disk/azure/scsi1/lun0
```

## Lifecycle

The module uses `ignore_changes` for `custom_data` to prevent VM
replacement when cloud-init configuration changes.

## References

- [Azure Linux VMs](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/)
- [Azure Managed Disks](https://learn.microsoft.com/en-us/azure/virtual-machines/managed-disks-overview)
- [Cloud-init](https://cloudinit.readthedocs.io/)

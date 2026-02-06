# Terraform Infrastructure

This directory contains Terraform code for deploying the `feedback` solution on
Azure. It wires together networking, Key Vault, secrets, container registry,
and a single Linux VM that runs the containers via Docker Compose.

## Modules

The Terraform code is organized as a set of reusable modules in
`terraform/modules` directory.

### Cloudflare

I used cloudflare to create DNS cname record in my existing domain. The cname
points to the Azure VM's public DNS name.

The module is only provisioned when the `domain_name` variable is set.
If `domain_name` is not set, the module is not provisioned and the Azure
VM's public name is used directly.

Please check the module's [README][8] for more information.

### Resource Group

The `resource_group` module provisions an Azure resource group where all other
resources are created.

Please check the module's [README][1] for more information.

### Networking

The `networking` module provisions an Azure Virtual Network, subnet, security
group and public IP address for the VM.

Please check the module's [README][2] for more information.

### Container Registry

The `container_registry` module provisions an Azure Container Registry (ACR)
where the Docker images for the application are stored.

Please check the module's [README][6] for more information.

### Container Image Push

The `container_image_push` module builds and pushes Docker images to the ACR.
Please check the module's [README][7] for more information.

### Key Vault

The `key_vault` module provisions an Azure Key Vault and a user-assigned managed
identity for the VM to access the Key Vault. Please check the module's [README][3]
for more information.

### Secrets

The `secrets` module generates random passwords for the database users and
stores them in Key Vault. It also stores the Asana credentials in Key Vault.
Please check the module's [README][4] for more information.

### Compute

The `compute` module provisions an Azure Linux VM that runs the application
containers via Docker Compose. Please check the module's [README][5] for more
information.

### Root Terraform Module

Main Terraform module is in `terraform/environments/prod`. It composes all of the
above modules to provision the complete infrastructure for the `feedback`
application.

## Secrets architecture

All application secrets live in two **Azure Key Vault** secrets:

- `<app_name>-asana-credentials` – JSON blob with Asana token, workspace GID,
  and project GID.
- `<app_name>-database-passwords` – JSON blob with passwords:
  - `postgres_password` - PostgreSQL superuser password
  - `migration_password` - Password for the migration user
  - `web_app_password` - Password for the web app user
  - `analysis_app_password` - Password for the analysis app user

The Key Vault itself and the VM’s managed identity are created by the
`key_vault` module.

### How secrets are created

The `secrets` module does the following:

- Uses **ephemeral** `random_password` resources to generate strong passwords
  for all database users (32 characters, including special characters).
- Writes those passwords once into Key Vault using the write‑only `value_wo`
  attribute and a `lifecycle.ignore_changes` block. This avoids regenerating or
  re‑reading passwords on later runs.
- Asana credentials are provided as input variables and stored in the secret
  using `value_wo` (write‑only) attribute as well.

Sensitive values never appear in Terraform outputs or in plain text in
Terraform state because ephemeral resources and `value_wo` attribute is used.

### How the VM uses secrets

The compute module attaches the user‑assigned managed identity to the VM and
grants it `Key Vault Secrets User` on the vault.

During provisioning, the VM:

1. Logs into Azure using the managed identity (`az login --identity`).
2. Reads the two Key Vault secrets above with `az keyvault secret show`.
3. Writes an `.env` file under `/opt/<app_name>` containing:
   - DB user names and passwords
   - Asana token, workspace GID, and project GID
   - Domain (`fqdn`) and admin email
4. Logs into ACR, pulls the images and runs `docker compose -f
   docker-compose.prod.yml up -d`.

Docker compose will read configuration exclusively from this `.env` file. No
secrets are baked into images or templates.

## Running Terraform for prod

- Change into the prod environment directory:

```bash
cd terraform/environments/prod
```

- Log into Azure and select the subscription:

```bash
az login
az account show --query id -o tsv   # used below as subscription_id
```

- Provide sensitive values via environment variables (recommended):

```bash
export TF_VAR_asana_token="..."
export TF_VAR_asana_workspace_gid="..."
export TF_VAR_asana_project_gid="..."
# Optional token for Terraform Cloudflare provider if using Cloudflare DNS
# e.g. var.domain_name is set.
export CLOUDFLARE_API_TOKEN=="..."
```

- Review and, if needed, edit `terraform.tfvars` for non‑sensitive values
   (domain name, location, SSH key, VM filter).

- Initialize and apply:

```bash
terraform init
terraform apply -var-file=terraform.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)"
```

After apply completes, cloud‑init and the provision scripts will install
Docker, retrieve secrets, pull images, and start the feedback containers.
This logic is defined in the [compute module][5] using scripts in
`modules/compute/scripts` and templates in `modules/compute/templates`.

For application‑level behavior, see the [feedback app][9], [nginx][10] and
[db][11] documentation.

[1]: modules/resource_group/README.md
[2]: modules/networking/README.md
[3]: modules/key_vault/README.md
[4]: modules/secrets/README.md
[5]: modules/compute/README.md
[6]: modules/container_registry/README.md
[7]: modules/container_image_push/README.md
[8]: modules/cloudflare/README.md
[9]: ../app/feedback/README.md
[10]: ../app/nginx/README.md
[11]: ../app/db/README.md

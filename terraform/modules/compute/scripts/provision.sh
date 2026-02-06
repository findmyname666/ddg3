#!/bin/bash
set -euo pipefail

# shellcheck disable=SC2154  # Variables provided by Terraform templatefile()

# This script runs as UBUNTU USER (non-root) and handles:
# - Azure login with managed identity (creds cached in ~/.azure/)
# - Retrieving secrets from Azure Key Vault
# - Creating .env file
# - Logging into Azure Container Registry
# - Pulling container images
# - Starting Docker services

APP_DIR="/opt/${app_name}"
cd "$APP_DIR" || exit 1

# Source common functions
# shellcheck source=terraform/modules/compute/scripts/common.sh
source "$APP_DIR/common.sh"

log_section "${app_name} Application Provision"

log_info "Starting at $(date)"
log_info "Running as user: $(whoami)"

# ============================================================================
# 1. Azure Login (credentials cached per user in ~/.azure/)
# ============================================================================
log_section "1. Azure Login"

log_info "Logging in to Azure with managed identity..."
az login --identity
log_success "Azure login successful"

# ============================================================================
# 2. Retrieve Secrets from Azure Key Vault
# ============================================================================
log_section "2. Retrieving Secrets from Key Vault"

# Retrieve Asana credentials from Key Vault
# shellcheck disable=SC2154  # key_vault_name provided by Terraform
log_info "Retrieving Asana credentials from ${key_vault_name}..."

ASANA_JSON=$(az keyvault secret show \
  --vault-name "${key_vault_name}" \
  --name "${app_name}-asana-credentials" \
  --query value -o tsv)
ASANA_TOKEN=$(echo "$ASANA_JSON" | jq -r '.asana_token')
ASANA_WORKSPACE_GID=$(echo "$ASANA_JSON" | \
  jq -r '.asana_workspace_gid')
ASANA_PROJECT_GID=$(echo "$ASANA_JSON" | \
  jq -r '.asana_project_gid')

# Retrieve database passwords from Key Vault
log_info "Retrieving database passwords..."

DB_PASSWORDS_JSON=$(az keyvault secret show \
  --vault-name "${key_vault_name}" \
  --name "${app_name}-database-passwords" \
  --query value -o tsv)
POSTGRES_PASSWORD=$(echo "$DB_PASSWORDS_JSON" | \
  jq -r '.postgres_password')
MIGRATION_PASSWORD=$(echo "$DB_PASSWORDS_JSON" | \
  jq -r '.migration_password')
WEB_APP_PASSWORD=$(echo "$DB_PASSWORDS_JSON" | \
  jq -r '.web_app_password')
ANALYSIS_APP_PASSWORD=$(echo "$DB_PASSWORDS_JSON" | \
  jq -r '.analysis_app_password')

log_success "All secrets retrieved successfully"

# ============================================================================
# 3. Create .env File
# ============================================================================
log_section "3. Creating Environment Configuration"

log_info "Writing .env file..."

# shellcheck disable=SC2154  # fqdn, admin_email from Terraform
cat > "$APP_DIR/.env" <<EOF
# Database Users
DB_USER_MIGRATION_NAME='migration_user'
DB_USER_WEB_NAME='web_app'
DB_USER_ANALYSIS_NAME='feedback_analysis_app'

# Database Passwords (wrapped in single quotes to prevent $ interpolation)
DB_USER_POSTGRES_PASSWORD='$POSTGRES_PASSWORD'
DB_USER_MIGRATION_PASSWORD='$MIGRATION_PASSWORD'
DB_USER_WEB_PASSWORD='$WEB_APP_PASSWORD'
DB_USER_ANALYSIS_PASSWORD='$ANALYSIS_APP_PASSWORD'

# Asana Configuration (wrapped in single quotes to prevent $ interpolation)
ASANA_TOKEN='$ASANA_TOKEN'
ASANA_WORKSPACE_GID='$ASANA_WORKSPACE_GID'
ASANA_PROJECT_GID='$ASANA_PROJECT_GID'

# Application Configuration
DOMAIN='${fqdn}'
ADMIN_EMAIL='${admin_email}'
EOF

chmod 600 "$APP_DIR/.env"

log_success ".env file created successfully"

# ============================================================================
# 4. Login to Azure Container Registry
# ============================================================================
log_section "4. Azure Container Registry Login"

# shellcheck disable=SC2154  # acr_name provided by Terraform
log_info "Logging in to ACR: ${acr_name}..."
az acr login --name "${acr_name}"
log_success "ACR login successful"

# ============================================================================
# 5. Pull Container Images
# ============================================================================
log_section "5. Pulling Container Images"

log_info "Pulling images from ACR..."
docker compose -f docker-compose.prod.yml pull
log_success "All images pulled successfully"

# ============================================================================
# 6. Start Docker Services
# ============================================================================
log_section "6. Starting Docker Services"

log_info "Starting all services..."
docker compose -f docker-compose.prod.yml up -d
# Wait for services to be healthy
log_info "Waiting for services to be healthy..."

sleep 10

echo ""
log_section "Provision Complete"
log_success "Provision completed at $(date)"

echo ""
log_info "Service status:"
docker compose -f docker-compose.prod.yml ps

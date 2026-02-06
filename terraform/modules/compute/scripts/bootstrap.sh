#!/bin/bash
set -euo pipefail

# shellcheck disable=SC2154  # Variables provided by Terraform templatefile()

# This script runs as ROOT and handles system-level configuration:
# - Firewall configuration
# - Docker / Azure cli installation
# - Fail2ban setup
# - SSL certificate acquisition
# Then delegates to provision.sh (runs as ubuntu user) for:
# - Azure login and secret retrieval
# - ACR login and image pulling
# - Docker service startup

APP_DIR="/opt/${app_name}"

# Source common functions
# shellcheck source=terraform/modules/compute/scripts/common.sh
source "$APP_DIR/common.sh"

log_section "${app_name} System Bootstrap"
log_info "Starting at $(date)"
log_info "Running as user: $(whoami)"

# ============================================================================
# 1. Configure Firewall
# ============================================================================
log_section "1. Configuring Firewall"

log_info "Resetting firewall rules..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

log_info "Allowing required ports..."
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP (for certbot)'
ufw allow 443/tcp comment 'HTTPS (HTTP/2)'
ufw allow 443/udp comment 'HTTP/3 (QUIC)'

log_info "Enabling firewall..."
ufw --force enable

log_success "Firewall configured"

# ============================================================================
# 2. Mount Data Disk
# ============================================================================
log_section "2. Mounting Data Disk"

DATA_DISK="/dev/disk/azure/scsi1/lun0"
MOUNT_POINT="/mnt/db"
VOLUME_DIR="postgresql"

log_info "Waiting for data disk to be available..."

# Wait up to 30 seconds for the disk to appear
for i in {1..30}; do
  if [ -e "$DATA_DISK" ]; then
    log_success "Data disk found at $DATA_DISK"
    break
  fi

  if [ "$i" -eq 30 ]; then
    log_error "Data disk not found after 30 seconds"
    exit 1
  fi

  sleep 1
done

# Check if disk is already formatted
if ! blkid "$DATA_DISK" > /dev/null 2>&1; then
  log_info "Formatting data disk with ext4 filesystem..."
  mkfs.ext4 -F "$DATA_DISK"
  log_success "Data disk formatted"
fi

# Create mount point
log_info "Creating mount point at $MOUNT_POINT..."
mkdir -p "$MOUNT_POINT"

# Get UUID for fstab entry (more reliable than device path)
DISK_UUID=$(blkid -s UUID -o value "$DATA_DISK")
log_info "Data disk UUID: $DISK_UUID"

# Check if already in fstab
if ! grep -q "$DISK_UUID" /etc/fstab; then
  log_info "Adding data disk to /etc/fstab..."
  # Mount options optimized for database workload:
  # - noatime: Don't update access time (reduces I/O, PostgreSQL doesn't need it)
  # - nofail: Continue boot even if disk fails to mount
  # - discard: Enable TRIM for SSD (Azure Premium SSD)
  echo "UUID=$DISK_UUID $MOUNT_POINT ext4 defaults,noatime,nodiratime,nofail 0 2" >> /etc/fstab
  log_success "Added to fstab with optimized mount options"
fi

# Mount the disk
if ! mountpoint -q "$MOUNT_POINT"; then
  log_info "Mounting data disk..."
  mount "$MOUNT_POINT"
  log_success "Data disk mounted at $MOUNT_POINT"
fi

# Verify mount
if ! mountpoint -q "$MOUNT_POINT"; then
  log_error "Failed to mount data disk"
  exit 1
fi

# Create directory for PSQL data
log_info "Creating PSQL data directory..."
mkdir -p "$MOUNT_POINT/$VOLUME_DIR"

# PSQL UID/GID varies by base image:
# - Alpine-based images (postgres:18-alpine): UID 70
# - Debian-based images (postgres:18): UID 999
# We're using postgres:18-alpine, so we use UID 70
# See: https://github.com/docker-library/postgres/blob/master/18/alpine3.23/Dockerfile#L11
POSTGRES_UID=70
POSTGRES_GID=70

log_info "Setting ownership to $POSTGRES_UID:$POSTGRES_GID ..."
chown -R "$POSTGRES_UID":"$POSTGRES_GID" "$MOUNT_POINT/$VOLUME_DIR"
chmod 700 "$MOUNT_POINT/$VOLUME_DIR"  # PostgreSQL requires 0700 permissions
log_success "PSQL data directory created at $MOUNT_POINT/$VOLUME_DIR"

# ============================================================================
# 3. Configure APT repositories for Azure CLI and Docker
# ============================================================================
log_section "3. Configuring APT repositories for Azure CLI and Docker"

# Prepare keyrings directory
install -m 0755 -d /etc/apt/keyrings

# Add Microsoft repository
add_apt_repository \
    "microsoft" \
    "https://packages.microsoft.com/keys/microsoft.asc" \
    "https://packages.microsoft.com/repos/azure-cli/" \
    "main"

# Add Docker repository
add_apt_repository \
    "docker" \
    "https://download.docker.com/linux/ubuntu/gpg" \
    "https://download.docker.com/linux/ubuntu" \
    "stable"

log_success "APT repositories configured"

# ============================================================================
# 4. Installing Azure CLI and Docker
# ============================================================================
log_section "4. Installing Azure CLI and Docker"

log_info "Updating package lists..."
apt_update

log_info "Installing packages..."
apt_install azure-cli docker-ce docker-ce-cli containerd.io docker-compose-plugin

log_success "Packages installed"

log_info "Adding ubuntu user to docker group..."
usermod -aG docker ubuntu

log_info "Enabling and starting Docker service..."
systemctl enable docker
systemctl start docker

log_success "Docker configured"

# ============================================================================
# 5. Configure Fail2ban
# ============================================================================
log_section "5. Configuring Fail2ban"

log_info "Creating fail2ban configuration..."
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

log_info "Enabling and restarting fail2ban..."
systemctl enable fail2ban
systemctl restart fail2ban

log_success "Fail2ban configured"

# ============================================================================
# 6. Obtain SSL Certificate
# ============================================================================
log_section "6. Obtaining SSL Certificate"
# shellcheck disable=SC2154  # Variables from Terraform
log_info "Requesting certificate for ${fqdn}..."

# shellcheck disable=SC2154
certbot certonly --standalone \
  -d "${fqdn}" \
  --non-interactive \
  --agree-tos \
  --email "${admin_email}" \
  --preferred-challenges http

log_info "Enabling certbot auto-renewal timer..."
systemctl enable certbot.timer
systemctl start certbot.timer

log_success "SSL certificate obtained and auto-renewal configured"

# ============================================================================
# 7. Configure Analysis Timer
# ============================================================================
log_section "7. Configuring Analysis Timer"

log_info "Reloading systemd daemon..."
systemctl daemon-reload

log_info "Enabling ${app_name}-analysis.timer..."
systemctl enable --now "${app_name}-analysis.timer"

log_success "Analysis timer configured (will start on boot, runs every 4 hours)"

# ============================================================================
# 8. Run Provision Script as Ubuntu User
# ============================================================================
log_section "8. Running Application Provision"
log_info "System configuration complete"

# Fix ownership of application directory so ubuntu user can write files
log_info "Setting ownership of $${APP_DIR} to ubuntu:ubuntu..."
chown -R ubuntu:ubuntu "$APP_DIR"

log_info "Delegating to provision script (running as ubuntu user)..."

# Run provision.sh as ubuntu user
su - ubuntu -c "$APP_DIR/provision.sh"

echo ""
log_section "Bootstrap Complete"
log_success "Bootstrap completed at $(date)"
log_success "${app_name} is ready!"

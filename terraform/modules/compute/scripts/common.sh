#!/bin/bash
# Common functions and variables for bootstrap and provision scripts
# This file should be sourced by other scripts, not executed directly

# Environment variables for non-interactive apt
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none

# Common variables
#
# Distribution codename (jammy, focal, etc.)
DIST="$(lsb_release -cs)"
# Architecture (amd64, arm64, etc.)
ARCH="$(dpkg --print-architecture)"

# Logging functions with timestamps
log_info() {
    printf "[%s] INFO: %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

log_success() {
    printf "[%s] SUCCESS: %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

log_error() {
    printf "[%s] ERROR: %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2
}

log_section() {
    printf "\n"
    printf "============================================================================\n"
    printf "%s\n" "$*"
    printf "============================================================================\n"
}

# Add APT repository with GPG key (DEB822 format)
# Usage: add_apt_repository <name> <key_url> <uri> <suite> <components>
add_apt_repository() {
    local name="$1"
    local key_url="$2"
    local uri="$3"
    local components="$4"

    log_info "Adding ${name} repository..."

    # Download and install GPG key
    curl -fsSL "${key_url}" | gpg --dearmor -o "/etc/apt/keyrings/${name}.gpg"
    chmod a+r "/etc/apt/keyrings/${name}.gpg"

    # Add repository in DEB822 format (.sources file)
    cat > "/etc/apt/sources.list.d/${name}.sources" <<EOF
Types: deb
URIs: ${uri}
Suites: ${DIST}
Components: ${components}
Architectures: ${ARCH}
Signed-by: /etc/apt/keyrings/${name}.gpg
EOF

    log_success "${name} repository added"
}

# Install packages with apt (non-interactive)
# Usage: apt_install <package1> [package2] [...]
apt_install() {
    apt-get install -y "$@"
}

# Update package lists with apt (non-interactive)
apt_update() {
    apt-get update
}

# Error handler
handle_error() {
    log_error "Script failed at line $1"
    exit 1
}

# Set up error handling
trap 'handle_error $LINENO' ERR

variable "acr_login_server" {
  type        = string
  description = "Azure Container Registry login server URL"
}

variable "acr_name" {
  type        = string
  description = "Azure Container Registry name"
}

variable "admin_email" {
  type        = string
  description = "Admin email for SSL certificates"
}

variable "app_name" {
  type        = string
  description = "Application name used for resource naming"
}

variable "container_images" {
  type = object({
    db = object({
      name = string
      tag  = string
    })
    feedback = object({
      name = string
      tag  = string
    })
    nginx = object({
      name = string
      tag  = string
    })
  })
  description = "Container image references from ACR"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "fqdn" {
  type        = string
  description = "Fully qualified domain name for the application (e.g., feedduck.example.com)"
}

variable "key_vault_id" {
  type        = string
  description = "Key Vault ID"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "public_ip_id" {
  type        = string
  description = "Public IP ID"
}

variable "resource_group_id" {
  type        = string
  description = "Resource group ID"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID"
}

variable "vm_identity_id" {
  type        = string
  description = "VM managed identity ID"
}

variable "vm_disk_data_size_gb" {
  type        = number
  description = "Size of the data disk for database storage in GB"
  default     = 10
}

variable "vm_size" {
  type        = string
  description = "VM size"
  default     = "Standard_B2s"
}

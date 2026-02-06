variable "admin_email" {
  type        = string
  description = "Admin email for SSL certificates and notifications"
}

variable "app_name" {
  type        = string
  description = "Application name used for resource naming"
}

variable "asana_project_gid" {
  type        = string
  description = "Asana project GID"
  sensitive   = true
}

variable "asana_token" {
  type        = string
  description = "Asana API token (will be stored in Key Vault)"
  sensitive   = true
}

variable "asana_workspace_gid" {
  type        = string
  description = "Asana workspace GID"
  sensitive   = true
}

variable "domain_name" {
  type        = string
  description = <<-EOT
  Domain name for the application. If not set, Azure's auto-generated FQDN
  will be used and Cloudflare DNS will not be provisioned.
  EOT
  default     = null
}

variable "environment" {
  type        = string
  description = "Environment name"
  default     = "prod"
}

variable "location" {
  type        = string
  description = "Azure region for resources"
  default     = "eastus"
}

variable "ssh_allowed_ips" {
  type        = list(string)
  description = "List of IP addresses allowed to SSH to the VM"
  default     = ["0.0.0.0/0"] # Restrict this in production!
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "vm_disk_data_size_gb" {
  type        = number
  description = "Size of the data disk for database storage in GB"
  default     = 10
}

variable "vm_max_memory_gb" {
  type        = number
  description = "Maximum memory in GB for VM size filtering"
  default     = 10
}

variable "vm_max_vcpus" {
  type        = number
  description = "Maximum number of vCPUs for VM size filtering (for cost control)"
  default     = 8
}

variable "vm_min_memory_gb" {
  type        = number
  description = "Minimum memory in GB for VM size filtering"
  default     = 1
}

variable "vm_min_vcpus" {
  type        = number
  description = "Minimum number of vCPUs for VM size filtering"
  default     = 1
}

variable "vm_size_filter_regex" {
  type        = string
  description = "Regex pattern to filter available VM sizes (e.g., '^Standard_(B[1-4]|DC[1-8]|L[2-8])' for small VMs)"
  default     = "^Standard_(B[1-8]|DC[1-8]|L[2-8]|EC[2-8]|FX[2-8])"
}

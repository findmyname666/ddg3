variable "app_name" {
  type        = string
  description = "Application name used for resource naming"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g., dev, staging, prod)"
}

variable "grant_vm_push_access" {
  type        = bool
  description = "Grant VM push access to ACR (in addition to pull)"
  default     = false
}

variable "location" {
  type        = string
  description = "Azure region where the ACR will be deployed"
}

variable "network_rule_set" {
  type = object({
    default_action = string
    ip_rules       = list(string)
  })
  description = "Network rules for ACR (Premium SKU only)"
  default     = null
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Enable public network access to ACR"
  default     = true
}

variable "resource_group_id" {
  type        = string
  description = "Resource group ID where ACR will be created"
}

variable "sku" {
  type        = string
  description = "ACR SKU tier (Basic, Standard, Premium)"
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "SKU must be one of: Basic, Standard, Premium"
  }
}

variable "vm_identity_principal_id" {
  type        = string
  description = "VM managed identity principal ID for ACR access"
}

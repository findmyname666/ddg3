variable "app_name" {
  type        = string
  description = "Application name used for resource naming"
  default     = "feedduck"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_id" {
  type        = string
  description = "Resource group ID"
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID"
}


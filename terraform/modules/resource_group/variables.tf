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

variable "app_name" {
  type        = string
  description = "Application name"
}

variable "asana_project_gid" {
  type        = string
  description = "Asana project GID"
  sensitive   = true
}

variable "asana_token" {
  type        = string
  description = "Asana API token"
  sensitive   = true
}

variable "asana_workspace_gid" {
  type        = string
  description = "Asana workspace GID"
  sensitive   = true
}

variable "key_vault_id" {
  type        = string
  description = "Key Vault ID"
}

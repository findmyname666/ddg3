variable "acr_login_server" {
  type        = string
  description = "ACR login server URL (e.g., acrfeedduckprod123456.azurecr.io)"
}

variable "acr_name" {
  type        = string
  description = "Azure Container Registry name (used for 'az acr login')"
}

variable "force_rebuild" {
  type        = bool
  description = "Force rebuild on every terraform apply (uses timestamp trigger)"
  default     = false
}

variable "images" {
  type = map(object({
    name            = string
    tag             = string
    dockerfile_path = string
    context_path    = string
    build_args      = optional(map(string), null)
  }))
  description = <<-EOT
    Map of images to build and push to ACR.
    All paths are relative to the var.working_directory.

    - name: Image name (repository name in ACR)
    - tag: Image tag (e.g., "0.0.1", "1.0.0")
    - dockerfile_path: Path to Dockerfile
    - context_path: Docker build context path
    - build_args: Optional build arguments

    Example:
    images = {
      web = {
        name            = "feedduck-web"
        tag             = "0.0.1"
        dockerfile_path = "app/Dockerfile"
        context_path    = "app"
        build_args      = { ENV = "production" }
      }
    }
  EOT
  default     = {}
}

variable "working_directory" {
  type        = string
  description = "Working directory for docker build commands"
  default     = "."
}

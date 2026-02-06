# Container Image Push Module

Terraform module for building and pushing Docker images to Azure Container
Registry (ACR) using Azure CLI authentication.

## Security Features

- **No passwords in logs** - Uses `az acr login` instead of admin credentials
- **No passwords in state** - Credentials never stored in Terraform state
- **Uses Azure CLI authentication** - Leverages your existing Azure login
- **Secure by default** - No sensitive data exposure

## Prerequisites

1. **Azure CLI installed** on the machine running Terraform
2. **Logged into Azure**: `az login`
3. **Docker installed** and running
4. **ACR already created** (see [container_registry module][2])

## Usage

### Basic Example

```hcl
module "container_registry" {
  source = "../../modules/container_registry"

  app_name          = "feedduck"
  environment       = "prod"
  location          = "westus2"
  resource_group_id = module.resource_group.id
}

module "push_images" {
  source = "../../modules/container_image_push"

  acr_name         = module.container_registry.name
  acr_login_server = module.container_registry.login_server

  working_directory = "${path.root}/../../"

  images = {
    web = {
      name            = "feedduck-web"
      tag             = "0.0.1"
      dockerfile_path = "app/Dockerfile"
      context_path    = "app"
    }
  }

  # Ensure ACR is created first
  depends_on = [module.container_registry]
}
```

## How It Works

There is a shell script that is executed by the null_resource. The script does
the following:

- Authenticates to ACR using `az acr login`
- Builds the Docker image using `docker build`
- Pushes the image to ACR using `docker push`

The module rebuilds images when:

- Dockerfile changes (detected via `filemd5()`)
- ACR name/server changes
- Image name or tag changes
- `force_rebuild = true` is set

**Versioning Strategy:**

- Use explicit version tags (e.g., `v0.0.1`, `v0.0.2`, `v1.0.0`)
- Bump the version tag when you want to rebuild and redeploy
- This gives you full control over when images are rebuilt

### "docker: command not found"

Install Docker. See [Docker Installation][1].

### Images rebuild on every apply

If you want to force a rebuild, either:

- Change the image tag (e.g., from `v0.0.1` to `v0.0.2`)
- Set `force_rebuild = true` in the module call
- Modify the Dockerfile

## Limitations

- Requires Azure CLI and Docker on the machine running Terraform
- Builds happen on local machine, not in Azure
- Not suitable for very large images

## Alternative

Consider using CI/CD pipelines instead.

## References

- [Azure CLI - az acr login](https://learn.microsoft.com/en-us/cli/azure/acr#az-acr-login)
- [ACR Authentication](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-authentication)
- [Terraform null_resource](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource)

[1]: https://docs.docker.com/engine/install/
[2]: ../container_registry/README.md

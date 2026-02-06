# Build and push Docker image to ACR using Azure CLI
resource "null_resource" "build_and_push" {
  for_each = var.images

  triggers = {
    # Rebuild when these change
    acr_name        = var.acr_name
    image_name      = each.value.name
    image_tag       = each.value.tag
    dockerfile_path = each.value.dockerfile_path
    context_path    = each.value.context_path

    # Rebuild when Dockerfile changes
    dockerfile_hash = fileexists(each.value.dockerfile_path) ? filemd5(each.value.dockerfile_path) : ""

    # Force rebuild flag
    force_rebuild = var.force_rebuild ? timestamp() : ""
  }

  # Build and push using Azure CLI (no password in logs!)
  provisioner "local-exec" {
    command = <<-EOT
      set -eu

      echo "$PWD"

      echo "=================================================================="
      echo "Logging into ACR using Azure CLI (no password exposure)..."
      echo "=================================================================="

      az acr login --name "${var.acr_name}"


      echo "=================================================================="
      echo "Building image: ${each.value.name}:${each.value.tag}"
      echo "=================================================================="

      docker build \
        -t "${var.acr_login_server}/${each.value.name}":"${each.value.tag}" \
        ${each.value.build_args != null ? join(" ", [for k, v in each.value.build_args : "--build-arg ${k}=${v}"]) : ""} \
        -f ${each.value.dockerfile_path} \
        "${each.value.context_path}"

      echo "=================================================================="
      echo "Pushing image to ACR..."
      echo "=================================================================="

      docker push "${var.acr_login_server}/${each.value.name}":"${each.value.tag}"

      echo ""
      echo "=================================================================="
      echo "Successfully pushed ${var.acr_login_server}/${each.value.name}:${each.value.tag}"
      echo "=================================================================="
      echo ""
    EOT

    working_dir = var.working_directory
  }

  # Optional: Cleanup local image after push
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "=================================================================="
      echo "Cleaning up local image (if exists)..."
      echo "=================================================================="

      docker rmi "${self.triggers.image_name}":"${self.triggers.image_tag}" 2>/dev/null || true
    EOT

    on_failure = continue
  }
}

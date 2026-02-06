output "acr_login_server" {
  value       = module.container_registry.login_server
  description = "ACR login server URL"
}

output "acr_name" {
  value       = module.container_registry.name
  description = "ACR name"
}

output "app_url" {
  value       = "https://${local.app_fqdn}"
  description = "URL of the application"
}

output "image_pushed" {
  value       = module.push_images.pushed_images
  description = "List of images pushed to ACR"
}

output "image_references" {
  value       = module.push_images.image_references
  description = "Map of image references with full paths"
}

output "key_vault_name" {
  value       = module.key_vault.name
  description = "Name of the Key Vault containing secrets"
}

output "resource_group_name" {
  value       = module.resource_group.name
  description = "Name of the resource group"
}

output "ssh_command" {
  value       = "ssh ubuntu@${module.networking.public_ip_address}"
  description = "SSH command to connect to the VM"
}

output "vm_fqdn" {
  value       = module.networking.fqdn
  description = "Fully qualified domain name"
}

output "vm_public_ip_address" {
  value       = module.networking.public_ip_address
  description = "Public IP address of the VM"
}

output "vm_selected_size" {
  value       = local.first_matching_vm
  description = "Auto-selected VM size (first match from filtered list)"
}

# Uncomment to debug VM SKU selection issues
# VM SKU availability outputs
# output "module_raw_output" {
#   value       = module.compute_skus.vms.names.matching
#   description = "Raw output from the Azure-Terraformer module (before regex filtering)"
# }
#
# output "available_vm_sizes" {
#   value       = local.sorted_vm_names
#   description = "List of available VM sizes in the region (filtered by regex and vCPU constraints)"
# }
#
# output "available_vm_details" {
#   value = [
#     for vm in module.compute_skus.vms.details.matching :
#     vm
#     if contains(local.filtered_vm_names, vm.name)
#   ]
#   description = "Detailed specifications of available VM sizes"
# }
#
# output "vm_filter_summary" {
#   value = {
#     location          = var.location
#     name_filter_regex = var.vm_size_filter_regex
#     min_vcpus         = var.vm_min_vcpus
#     max_vcpus         = var.vm_max_vcpus
#     total_available   = length(local.all_available_vms)
#     filtered_count    = length(local.filtered_vm_names)
#     first_match       = local.first_matching_vm
#   }
#   description = "Summary of VM size filters applied"
# }

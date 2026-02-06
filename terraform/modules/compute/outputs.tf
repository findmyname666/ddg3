output "private_ip_address" {
  value       = azurerm_network_interface.this.private_ip_address
  description = "Private IP address"
}

output "vm_id" {
  value       = azurerm_linux_virtual_machine.this.id
  description = "Virtual machine ID"
}

output "vm_name" {
  value       = azurerm_linux_virtual_machine.this.name
  description = "Virtual machine name"
}

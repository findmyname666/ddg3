output "fqdn" {
  value       = azurerm_public_ip.this.fqdn
  description = "Fully qualified domain name in Azure"
}

output "nsg_id" {
  value       = azurerm_network_security_group.this.id
  description = "Network security group ID"
}

output "public_ip_address" {
  value       = azurerm_public_ip.this.ip_address
  description = "Public IP address"
}

output "public_ip_id" {
  value       = azurerm_public_ip.this.id
  description = "Public IP ID"
}

output "subnet_id" {
  value       = azurerm_subnet.this.id
  description = "Subnet ID"
}

output "vnet_id" {
  value       = azurerm_virtual_network.this.id
  description = "Virtual network ID"
}

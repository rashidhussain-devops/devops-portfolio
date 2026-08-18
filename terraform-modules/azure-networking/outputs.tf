output "vnet_id" {
  description = "Resource ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "subnet_ids" {
  description = "Map of subnet name to subnet resource ID."
  value       = { for k, v in azurerm_subnet.this : k => v.id }
}

output "resource_group_name" {
  value = local.resource_group_name
}

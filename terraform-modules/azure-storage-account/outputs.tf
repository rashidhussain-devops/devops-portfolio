output "storage_account_id" {
  value = azurerm_storage_account.this.id
}

output "primary_blob_endpoint" {
  value = azurerm_storage_account.this.primary_blob_endpoint
}

output "container_names" {
  value = [for c in azurerm_storage_container.this : c.name]
}

output "virtual_network_gateway_id" {
  value = azurerm_virtual_network_gateway.example.id
}

output "public_ip_address_primary" {
  value = azurerm_public_ip.primary.ip_address
}

output "virtual_network_gateway_id" {
  value = azurerm_virtual_network_gateway.example.id
}

output "bgp_peering_address" {
  value = azurerm_virtual_network_gateway.example.bgp_settings[0].peering_addresses[0].default_addresses[0]
}
output "public_ip_address_primary" {
  value = azurerm_public_ip.primary.ip_address
}
output "public_ip_address_secondary" {
  value = azurerm_public_ip.secondary.ip_address
}

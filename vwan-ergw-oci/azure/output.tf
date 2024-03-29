output "expressroute_circuit_servicekey" {
  value = azurerm_express_route_circuit.example.service_key
  sensitive = true
}
output "expressroute_circuit_id" {
  value = azurerm_express_route_circuit.example.id
}

output "virtual_network_gateway_id" {
  value = module.ergw.virtual_network_gateway_id
}

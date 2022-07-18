output "azfw_name" {
  value = module.azfw.name
}

output "hub_vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "hub_route_table_name" {
  value = azurerm_route_table.hubAzFW.name
}

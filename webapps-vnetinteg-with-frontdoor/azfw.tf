
resource "azurerm_route_table" "appservice" {
  name                          = "rt-appservice"
  resource_group_name           = azurerm_resource_group.example.name
  location                      = azurerm_resource_group.example.location
  disable_bgp_route_propagation = false

  route = [{
    name                   = "default"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = module.azfw.private_ip_address
  }]
}
resource "azurerm_subnet_route_table_association" "appservice" {
  subnet_id      = azurerm_subnet.appservice_azfw.id
  route_table_id = azurerm_route_table.appservice.id
}
module "azfw" {
  source = "../modules/azurefirewall-premium"
  rg = {
    name     = azurerm_resource_group.example.name
    location = azurerm_resource_group.example.location
  }
  name      = "afw-appservice"
  subnet_id = azurerm_subnet.azfw.id
}

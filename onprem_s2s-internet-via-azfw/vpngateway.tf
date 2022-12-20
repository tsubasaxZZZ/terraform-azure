module "vpngw" {
  source = "../modules/vpngateway"
  name   = "vpng-example"
  rg = {
    name     = azurerm_resource_group.example.name
    location = azurerm_resource_group.example.location
  }
  subnet_id = azurerm_subnet.vpngw.id

  bgp = {
    asn = var.vpngw_bgp_asn
  }
}

resource "azurerm_local_network_gateway" "example" {
  name                = "lng-onprem"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  gateway_address     = var.onprem_network.gateway_address

  bgp_settings {
    asn                 = var.onprem_network.bgp_asn
    bgp_peering_address = var.onprem_network.bgp_peering_address
  }
}

resource "azurerm_virtual_network_gateway_connection" "exmple" {
  name                = "onprem-to-azure"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  type                       = "IPsec"
  virtual_network_gateway_id = module.vpngw.virtual_network_gateway_id
  local_network_gateway_id   = azurerm_local_network_gateway.example.id

  enable_bgp = true

  shared_key = var.onprem_network.shared_key
}

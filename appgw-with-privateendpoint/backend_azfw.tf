module "azfw" {
  source = "../modules/azurefirewall-premium"

  rg = {
    name     = azurerm_resource_group.example.name
    location = azurerm_resource_group.example.location
  }
  id        = "example"
  subnet_id = azurerm_subnet.azfw.id
  sku       = "Premium"
}
resource "azurerm_route_table" "azfw" {
  name                = "route-azfw"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  route {
    name           = "default"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }
}

resource "azurerm_subnet_route_table_association" "azfw" {
  subnet_id      = azurerm_subnet.azfw.id
  route_table_id = azurerm_route_table.azfw.id
}
data "azurerm_monitor_diagnostic_categories" "azfw_diag_category" {
  resource_id = module.azfw.id
}

module "azfw_diag" {
  source                     = "../modules/diagnostic_logs"
  name                       = "diag"
  target_resource_id         = module.azfw.id
  log_analytics_workspace_id = module.la.id
  diagnostic_logs            = data.azurerm_monitor_diagnostic_categories.azfw_diag_category.logs
  retention                  = 30
}


// route table for AppGW-VM subnet
resource "azurerm_route_table" "default" {
  name                          = "rt-default"
  location                      = azurerm_resource_group.example.location
  resource_group_name           = azurerm_resource_group.example.name
  disable_bgp_route_propagation = true

  route = [
    {
      name                   = "default"
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = module.azfw.private_ip_address
    },
    {
      name                   = "to-appgw"
      address_prefix         = module.azure_subnet_addrs.network_cidr_blocks["appgw"]
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = module.azfw.private_ip_address
    },
  ]
}

resource "azurerm_subnet_route_table_association" "default" {
  count          = can(regex(".*BackendAzFW.*", var.pattern)) ? 1 : 0
  subnet_id      = azurerm_subnet.default.id
  route_table_id = azurerm_route_table.default.id
}

// route table for AppGW subnet
resource "azurerm_route_table" "appgw" {
  name                          = "rt-appgw"
  location                      = azurerm_resource_group.example.location
  resource_group_name           = azurerm_resource_group.example.name
  disable_bgp_route_propagation = true

  route = [
    {
      name                   = "to-default"
      address_prefix         = module.azure_subnet_addrs.network_cidr_blocks["default"]
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = module.azfw.private_ip_address
    },
  ]
}

resource "azurerm_subnet_route_table_association" "appgw" {
  count          = can(regex(".*BackendAzFW.*", var.pattern)) ? 1 : 0
  subnet_id      = azurerm_subnet.appgw.id
  route_table_id = azurerm_route_table.appgw.id
}

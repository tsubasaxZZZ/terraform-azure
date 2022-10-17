module "east" {
  source = "./modules/ergateway"
  name   = "ergw-east"
  rg = {
    name     = azurerm_resource_group.example.name
    location = var.azure_east.location
  }
  subnet_id = azurerm_subnet.east_vpngw.id
}

module "west" {
  source = "./modules/ergateway"
  name   = "ergw-west"
  rg = {
    name     = azurerm_resource_group.example.name
    location = var.azure_west.location
  }
  subnet_id = azurerm_subnet.west_vpngw.id
}

// ------------------------------------------
// ExpressRoute Gateway - MSEE
// ------------------------------------------
// ERGW(EAST) -> MSEE(EAST)
resource "azurerm_virtual_network_gateway_connection" "east2mseeeast" {
  name                = "east2mseeeast"
  location            = var.azure_east.location
  resource_group_name = azurerm_resource_group.example.name

  type                       = "ExpressRoute"
  virtual_network_gateway_id = module.east.virtual_network_gateway_id
  authorization_key          = var.msee_east[0].auth_key
  express_route_circuit_id   = var.msee_east[0].peering_url
}

// ERGW(WEST) -> MSEE(WEST)
resource "azurerm_virtual_network_gateway_connection" "west2mseewest" {
  name                = "west2mseewest"
  location            = var.azure_west.location
  resource_group_name = azurerm_resource_group.example.name

  type                       = "ExpressRoute"
  virtual_network_gateway_id = module.west.virtual_network_gateway_id
  authorization_key          = var.msee_west[0].auth_key
  express_route_circuit_id   = var.msee_west[0].peering_url
}

// ERGW(EAST) -> MSEE(WEST)
resource "azurerm_virtual_network_gateway_connection" "east2mseewest" {
  name                = "east2mseewest"
  location            = var.azure_east.location
  resource_group_name = azurerm_resource_group.example.name

  type                       = "ExpressRoute"
  virtual_network_gateway_id = module.east.virtual_network_gateway_id
  authorization_key          = var.msee_west[1].auth_key
  express_route_circuit_id   = var.msee_west[1].peering_url
}

// ERGW(WEST) -> MSEE(EAST)
resource "azurerm_virtual_network_gateway_connection" "west2mseeeast" {
  name                = "west2mseeeast"
  location            = var.azure_west.location
  resource_group_name = azurerm_resource_group.example.name

  type                       = "ExpressRoute"
  virtual_network_gateway_id = module.west.virtual_network_gateway_id
  authorization_key          = var.msee_east[1].auth_key
  express_route_circuit_id   = var.msee_east[1].peering_url
}
// ------------------------------------------
// ExpressRoute Gateway - D-MSEE
// ------------------------------------------
// D-MSEE(EAST) -> ERGW(EAST)
resource "azurerm_virtual_network_gateway_connection" "east2dmseeeast" {
  name                = "east2dmseeeast"
  location            = var.azure_east.location
  resource_group_name = azurerm_resource_group.example.name

  type                       = "ExpressRoute"
  virtual_network_gateway_id = module.east.virtual_network_gateway_id
  authorization_key          = var.dmsee_east[0].auth_key
  express_route_circuit_id   = var.dmsee_east[0].peering_url
}
// D-MSEE(WEST) -> ERGW(EAST)
resource "azurerm_virtual_network_gateway_connection" "east2dmseewest" {
  name                = "east2dmseewest"
  location            = var.azure_east.location
  resource_group_name = azurerm_resource_group.example.name

  type                       = "ExpressRoute"
  virtual_network_gateway_id = module.east.virtual_network_gateway_id
  authorization_key          = var.dmsee_west[0].auth_key
  express_route_circuit_id   = var.dmsee_west[0].peering_url
}

// D-MSEE(WEST) -> ERGW(WEST)
resource "azurerm_virtual_network_gateway_connection" "west2dmseewest" {
  name                = "west2dmseewest"
  location            = var.azure_west.location
  resource_group_name = azurerm_resource_group.example.name

  type                       = "ExpressRoute"
  virtual_network_gateway_id = module.west.virtual_network_gateway_id
  authorization_key          = var.dmsee_west[1].auth_key
  express_route_circuit_id   = var.dmsee_west[1].peering_url
}
// D-MSEE(EAST) -> ERGW(WEST)
resource "azurerm_virtual_network_gateway_connection" "west2dmseeeast" {
  name                = "west2dmseeeast"
  location            = var.azure_west.location
  resource_group_name = azurerm_resource_group.example.name

  type                       = "ExpressRoute"
  virtual_network_gateway_id = module.west.virtual_network_gateway_id
  authorization_key          = var.dmsee_east[1].auth_key
  express_route_circuit_id   = var.dmsee_east[1].peering_url
}
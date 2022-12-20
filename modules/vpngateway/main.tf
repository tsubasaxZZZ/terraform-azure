resource "azurerm_public_ip" "primary" {
  name                = "pip-${var.name}-primary"
  location            = var.rg.location
  resource_group_name = var.rg.name
  sku                 = "Standard"
  allocation_method   = "Static"
  zones               = ["1", "2", "3"]
}

resource "azurerm_public_ip" "secondary" {
  name                = "pip-${var.name}-secondary"
  location            = var.rg.location
  resource_group_name = var.rg.name
  sku                 = "Standard"
  allocation_method   = "Static"
  zones               = ["1", "2", "3"]
}
resource "azurerm_virtual_network_gateway" "example" {
  name                = var.name
  location            = var.rg.location
  resource_group_name = var.rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = true
  enable_bgp    = true
  sku           = var.sku

  ip_configuration {
    name                 = "vnetGatewayConfig-primary"
    public_ip_address_id = azurerm_public_ip.primary.id
    subnet_id            = var.subnet_id
  }
  ip_configuration {
    name                 = "vnetGatewayConfig-secondary"
    public_ip_address_id = azurerm_public_ip.secondary.id
    subnet_id            = var.subnet_id
  }
  bgp_settings {
    asn = var.bgp.asn
  }
}

resource "azurerm_public_ip" "example" {
  name                = "pip-${var.name}"
  location            = var.rg.location
  resource_group_name = var.rg.name

  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "example" {
  name                = var.name
  location            = var.rg.location
  resource_group_name = var.rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = true
  sku           = "Standard"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.example.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.subnet_id
  }

  bgp_settings {
    asn = var.bgp.asn
  }
}

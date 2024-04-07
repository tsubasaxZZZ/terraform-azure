resource "azurerm_public_ip" "primary" {
  name                = "pip-${var.name}-primary"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_virtual_network_gateway" "example" {
  name                = var.name
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  type     = "ExpressRoute"

  active_active = false
  sku           = var.sku

  ip_configuration {
    name                 = "ErGatewayConfig-primary"
    public_ip_address_id = azurerm_public_ip.primary.id
    subnet_id            = var.subnet_id
  }
}

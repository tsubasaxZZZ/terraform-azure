module "azfw_east" {
  source = "../modules/azurefirewall-premium"
  rg = {
    name     = azurerm_resource_group.example.name
    location = var.azure_east.location
  }
  id        = "east"
  name      = "azfw-east"
  subnet_id = azurerm_subnet.east_azfw.id
}
module "azfw_west" {
  source = "../modules/azurefirewall-premium"
  rg = {
    name     = azurerm_resource_group.example.name
    location = var.azure_west.location
  }
  id        = "west"
  name      = "azfw-west"
  subnet_id = azurerm_subnet.west_azfw.id
  zones     = null
}

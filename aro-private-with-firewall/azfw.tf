//-----------------------
// AzFW
//-----------------------
module "azfw" {
  source = "../modules/azurefirewall-premium"

  rg = {
    name     = azurerm_resource_group.example.name
    location = azurerm_resource_group.example.location
  }
  id        = random_string.uniqstr.result
  subnet_id = azurerm_subnet.azfw.id
  sku       = "Standard"
}
resource "azurerm_route_table" "azfw" {
  name                = "rt-azfw"
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
  #   diagnostic_logs            = data.azurerm_monitor_diagnostic_categories.azfw_diag_category.logs
  diagnostic_logs = data.azurerm_monitor_diagnostic_categories.azfw_diag_category.log_category_types
  retention       = 30
}

resource "azurerm_route_table" "aro" {
  name                          = "rt-aro"
  resource_group_name           = azurerm_resource_group.example.name
  location                      = azurerm_resource_group.example.location
  disable_bgp_route_propagation = false

  route = [
    {
      name                   = "default"
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = module.azfw.private_ip_address
    }
  ]
}

resource "azurerm_subnet_route_table_association" "master" {
  subnet_id      = azurerm_subnet.master.id
  route_table_id = azurerm_route_table.aro.id
}
resource "azurerm_subnet_route_table_association" "worker" {
  subnet_id      = azurerm_subnet.worker.id
  route_table_id = azurerm_route_table.aro.id
}

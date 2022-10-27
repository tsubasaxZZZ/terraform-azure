data "azurerm_monitor_diagnostic_categories" "azfw_east_diag_category" {
  resource_id = module.azfw_east.id
}

module "afw_east_diag" {
  source                     = "../modules/diagnostic_logs"
  name                       = "diag"
  target_resource_id         = module.azfw_east.id
  log_analytics_workspace_id = module.la.id
  diagnostic_logs            = data.azurerm_monitor_diagnostic_categories.azfw_east_diag_category.logs
  retention                  = 30
}
module "azfw_east" {
  source = "../modules/azurefirewall-premium"
  rg = {
    name     = azurerm_resource_group.example.name
    location = var.azure_east.location
  }
  id        = "east"
  name      = "azfw-east"
  subnet_id = azurerm_subnet.east_azfw.id

  azurefirewall_nat_rule = [
    {
      action   = "Dnat"
      name     = "DnatRuleCollection"
      priority = 500
      rule = [
        {
          name               = "SSH"
          source_addresses   = ["*"]
          destination_ports  = ["2222"]
          protocols          = ["TCP"]
          translated_address = module.vm_nva_east.network_interface_ipconfiguration[0].private_ip_address
          translated_port    = "22"
        },
        {
          name               = "RDP"
          source_addresses   = ["*"]
          destination_ports  = ["33389"]
          protocols          = ["TCP"]
          translated_address = module.vm_windows_east.network_interface_ipconfiguration[0].private_ip_address
          translated_port    = "3389"
        }
      ]
    }
  ]
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

resource "azurerm_route_table" "east_azfw" {
  name                = "route-east-azfw"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  route {
    name           = "default"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }
}

resource "azurerm_subnet_route_table_association" "east_azfw" {
  subnet_id      = azurerm_subnet.east_azfw.id
  route_table_id = azurerm_route_table.east_azfw.id
}

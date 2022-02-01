variable "resource_group_name" {
  default = "rg-azfw"
}
variable "location" {
  default = "japaneast"
}
variable "application_rule_collection_rule1" {
  default = [
    "*.teams.microsoft.com",
    "login.microsoftonline.com",
    "aadcdn.msftauth.net",
    "autologon.microsoftazuread-sso.com",
    "aadcdn.msauthimages.net",
    "statics.teams.cdn.office.net",
    "*.skype.com",
    "teams.microsoft.com",
    "outlook.office.com",
    "graph.microsoft.com",
    "substrate.office.com",
    "spoprod-a.akamaihd.net",
    "ifconfig.me",
  ]
}
variable "admin_username" {
  default = "azureuser"
}
variable "admin_password" {
  default = "Passw0rd1!"
}
variable "myipaddress" {

}

// 配列の配列でルートを指定する。1配列=1ルートテーブル
variable "udr_service_tags" {
  type    = list(list(string))
  default = [[]]
}

terraform {
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name
  location = var.location
}

resource "random_string" "uniqstr" {
  length  = 6
  special = false
  upper   = false
  keepers = {
    resource_group_name = azurerm_resource_group.example.name
  }
}

#################
# Log Analytics
#################
resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "la-aksdemo${random_string.uniqstr.result}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
}

#################
# VNET
#################
resource "azurerm_virtual_network" "example" {
  name                = "vnet-example"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "azfw" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

#################
# Route Table
#################

resource "azurerm_route_table" "example" {
  count               = length(var.udr_service_tags)
  name                = "rt-example${count.index}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  dynamic "route" {
    for_each = var.udr_service_tags[count.index]
    content {
      name                   = route.value
      address_prefix         = route.value
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = azurerm_firewall.example.ip_configuration.0.private_ip_address
    }
  }
}

/*
resource "azurerm_route_table" "example" {
  name                = "route-azfw"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_route" "alltags" {
  count                  = length(var.udr_service_tags)
  name                   = var.udr_service_tags[count.index]
  resource_group_name    = azurerm_resource_group.example.name
  route_table_name       = azurerm_route_table.example.name
  address_prefix         = var.udr_service_tags[count.index]
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.example.ip_configuration.0.private_ip_address
}

resource "azurerm_route" "azfw" {
  name                   = "toAppService"
  resource_group_name    = azurerm_resource_group.example.name
  route_table_name       = azurerm_route_table.example.name
  address_prefix         = "AppService"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.example.ip_configuration.0.private_ip_address
}
resource "azurerm_route" "internet" {
  name                = "toInternet"
  resource_group_name = azurerm_resource_group.example.name
  route_table_name    = azurerm_route_table.example.name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "Internet"
}
resource "azurerm_route" "avd" {
  name                   = "toAVD"
  resource_group_name    = azurerm_resource_group.example.name
  route_table_name       = azurerm_route_table.example.name
  address_prefix         = "WindowsVirtualDesktop"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.example.ip_configuration.0.private_ip_address
}

resource "azurerm_subnet_route_table_association" "example" {
  count          = length(var.udr_service_tags)
  subnet_id      = azurerm_subnet.default.id
  route_table_id = azurerm_route_table.example[count.index].id
}
*/

#################
# Windows VM
#################
resource "azurerm_public_ip" "winvm" {
  name                = "pip-winvm"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "winvm" {
  name                = "nic-winvm"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  ip_configuration {
    name                          = "configuration"
    subnet_id                     = azurerm_subnet.default.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.winvm.id
  }
}
resource "azurerm_windows_virtual_machine" "windows" {
  name                = "winvm"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_B2ms"
  zone                = 1
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.winvm.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-winvm"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  security_rule {
    name                       = "remote_access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.winvm.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "autoshutdown" {
  virtual_machine_id = azurerm_windows_virtual_machine.windows.id
  location           = azurerm_resource_group.example.location
  enabled            = true

  daily_recurrence_time = "0300"
  timezone              = "Tokyo Standard Time"

  notification_settings {
    enabled = false
  }
}

#######################
# Azure Firewall
#######################

resource "azurerm_public_ip" "example" {
  name                = "pip-azfw"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "example" {
  name                = "azfw"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.azfw.id
    public_ip_address_id = azurerm_public_ip.example.id
  }
}

resource "azurerm_firewall_application_rule_collection" "example" {
  name                = "rule1"
  azure_firewall_name = azurerm_firewall.example.name
  resource_group_name = azurerm_resource_group.example.name
  priority            = 500
  action              = "Allow"

  dynamic "rule" {
    for_each = concat(var.application_rule_collection_rule1, [azurerm_app_service.example.default_site_hostname])
    content {
      name             = rule.value
      source_addresses = ["*"]
      target_fqdns     = [rule.value]
      protocol {
        port = "443"
        type = "Https"
      }

    }
  }
}

resource "azurerm_firewall_nat_rule_collection" "example" {
  name                = "rule1"
  azure_firewall_name = azurerm_firewall.example.name
  resource_group_name = azurerm_resource_group.example.name
  priority            = 500
  action              = "Dnat"

  rule {
    name = "RDP"

    source_addresses = [
      var.myipaddress
    ]

    destination_ports = [
      "3389",
    ]

    destination_addresses = [
      azurerm_public_ip.example.ip_address
    ]

    translated_port = 3389

    translated_address = azurerm_network_interface.winvm.private_ip_address

    protocols = [
      "TCP",
    ]
  }
}

data "azurerm_monitor_diagnostic_categories" "azfw" {
  resource_id = azurerm_firewall.example.id
}

resource "azurerm_monitor_diagnostic_setting" "azfw" {
  name                       = "diag"
  target_resource_id         = azurerm_firewall.example.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id

  dynamic "log" {
    for_each = data.azurerm_monitor_diagnostic_categories.azfw.logs
    content {
      category = log.value
      enabled  = true
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = false

    retention_policy {
      days    = 0
      enabled = false
    }
  }
}


#######################
# App Service
#######################
resource "azurerm_app_service_plan" "example" {
  name                = "appserviceplan"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "example" {
  name                = "apps${random_string.uniqstr.result}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  app_service_plan_id = azurerm_app_service_plan.example.id

  site_config {
    linux_fx_version = "NODE|16-lts"
  }
}

data "azurerm_monitor_diagnostic_categories" "webapps" {
  resource_id = azurerm_app_service.example.id
}

resource "azurerm_monitor_diagnostic_setting" "webapps" {
  name                       = "diag"
  target_resource_id         = azurerm_app_service.example.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id

  dynamic "log" {
    for_each = data.azurerm_monitor_diagnostic_categories.webapps.logs
    content {
      category = log.value
      enabled  = true
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = false

    retention_policy {
      days    = 0
      enabled = false
    }
  }
}


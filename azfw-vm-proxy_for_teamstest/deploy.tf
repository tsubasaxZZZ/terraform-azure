variable "resource_group_name" {}
variable "location" {}
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
    "ifconfig.me"
  ]
}
variable "admin_username" {}
variable "admin_password" {}

terraform {
  required_version = "~> 0.14.3"
  required_providers {
    azurerm = {
      version = "=2.40.0"
    }
  }

}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name
  location = var.location
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

resource "azurerm_route_table" "example" {
  name                          = "route-azfw"
  location                      = azurerm_resource_group.example.location
  resource_group_name           = azurerm_resource_group.example.name
  disable_bgp_route_propagation = false

  route {
    name                   = "azfw"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.example.ip_configuration.0.private_ip_address
  }

}
resource "azurerm_subnet_route_table_association" "example" {
  subnet_id      = azurerm_subnet.default.id
  route_table_id = azurerm_route_table.example.id
}

#################
# Windows VM
#################
module "windows" {
  source              = "../modules/vm-windows"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  name                = "VM"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.default.id
  zone                = 1

}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "autoshutdown" {
  virtual_machine_id = module.windows.id
  location           = var.location
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
    for_each = var.application_rule_collection_rule1
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
      "*"
    ]

    destination_ports = [
      "3389",
    ]

    destination_addresses = [
      azurerm_public_ip.example.ip_address
    ]

    translated_port = 3389

    translated_address = module.windows.private_ip_address

    protocols = [
      "TCP",
    ]
  }
}

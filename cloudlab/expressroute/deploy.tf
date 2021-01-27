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

resource "azurerm_resource_group" "cloudlab" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "cloudlab" {
  name                = var.vnet_name
  address_space       = var.ip_range
  location            = azurerm_resource_group.cloudlab.location
  resource_group_name = azurerm_resource_group.cloudlab.name
}

resource "azurerm_subnet" "gateway" {
  name                 = var.subnet_name_gw
  resource_group_name  = azurerm_resource_group.cloudlab.name
  virtual_network_name = azurerm_virtual_network.cloudlab.name
  address_prefixes     = var.ip_subnet_gw
}

resource "azurerm_express_route_circuit" "cloudlab" {
  name                  = var.exrcircuit_name
  resource_group_name   = azurerm_resource_group.cloudlab.name
  location              = azurerm_resource_group.cloudlab.location
  service_provider_name = var.exrcircuit_provider
  peering_location      = var.exrcircuit_location
  bandwidth_in_mbps     = var.exrcircuit_bandwidth
  sku {
    tier   = var.exrcircuit_sku_tier
    family = var.exrcircuit_sku_family
  }
  allow_classic_operations = false
}

resource "azurerm_management_lock" "exrcircuit" {
  name       = azurerm_express_route_circuit.cloudlab.name
  scope      = azurerm_express_route_circuit.cloudlab.id
  lock_level = "CanNotDelete"
  notes      = "Locked"
}

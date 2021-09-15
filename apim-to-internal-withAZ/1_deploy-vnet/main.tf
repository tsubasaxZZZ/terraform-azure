terraform {
  required_version = "~> 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.76.0"
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

##############################
# VNET
##############################
resource "azurerm_virtual_network" "example" {
  name                = var.vnet_name
  address_space       = ["10.0.0.0/8"]
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
}

resource "azurerm_subnet" "default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.0.0/24"]
}
resource "azurerm_subnet" "apim" {
  name                 = var.subnet_name_for_apim
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints = [ "Microsoft.EventHub", "Microsoft.Storage", "Microsoft.Sql" ]
}

##############################
# NSG for APIM
##############################
resource "azurerm_network_security_group" "apim" {
  name                = "nsg-apim"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "Allow_All_Internet_Outbound"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}
resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.apim.id
  network_security_group_id = azurerm_network_security_group.apim.id
}
##############################
# Public IP address for APIM
##############################
resource "random_string" "piplabel" {
  length  = 8
  special = false
  upper   = false
  keepers = {
    "resource_group" = azurerm_resource_group.example.name
  }
}
resource "azurerm_public_ip" "example" {
  name                = var.pip_name_for_apim
  resource_group_name = azurerm_resource_group.example.name
  location            = var.location
  sku                 = "Standard"
  allocation_method   = "Static"
  domain_name_label   = "tsunomurapim${random_string.piplabel.result}"
}

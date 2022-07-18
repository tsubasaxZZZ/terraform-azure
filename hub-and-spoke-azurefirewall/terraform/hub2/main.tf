terraform {
  required_version = "~> 1.2.1"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "azurerm" {
  //use_oidc = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

module "hub2" {
  source         = "../"
  rg             = var.rg
  admin_username = var.admin_username
  admin_password = var.admin_password

  environment_name = var.environment_name

  hub_vnet    = var.hub_vnet
  spoke_vnet1 = var.spoke_vnet1
  spoke_vnet2 = var.spoke_vnet2
}

data "azurerm_virtual_network" "hub2" {
  depends_on = [
    module.hub2
  ]
  name                = module.hub2.hub_vnet_name
  resource_group_name = var.rg.name
}

data "azurerm_subnet" "gateway" {
  depends_on = [
    module.hub2
  ]
  name                 = "GatewaySubnet"
  resource_group_name  = var.rg.name
  virtual_network_name = module.hub2.hub_vnet_name
}

data "azurerm_firewall" "hub2" {
  depends_on = [
    module.hub2
  ]
  name                = module.hub2.azfw_name
  resource_group_name = var.rg.name
}

// ------------------------------------------
// - Connect to hub1
// - Route to hub1 spoke1 and spoke2
// ------------------------------------------
data "azurerm_virtual_network" "hub1" {
  name                = var.hub1.vnet_name
  resource_group_name = var.hub1.resource_group_name
}
resource "azurerm_virtual_network_peering" "hub1Tohub2" {
  name                      = "Hub1ToHub2"
  resource_group_name       = data.azurerm_virtual_network.hub1.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.hub1.name
  remote_virtual_network_id = data.azurerm_virtual_network.hub2.id
  allow_gateway_transit     = true
  use_remote_gateways       = false
  allow_forwarded_traffic   = true
}
resource "azurerm_virtual_network_peering" "hub2Tohub1" {
  name                      = "Hub2ToHub1"
  resource_group_name       = var.rg.name
  virtual_network_name      = data.azurerm_virtual_network.hub2.name
  remote_virtual_network_id = data.azurerm_virtual_network.hub1.id
  allow_gateway_transit     = false
  //use_remote_gateways       = true
  allow_forwarded_traffic = true
}

// Set route-table
data "azurerm_virtual_network" "hub1spoke1" {
  name                = var.hub1.spoke1_vnet_name
  resource_group_name = var.hub1.resource_group_name
}
data "azurerm_virtual_network" "hub1spoke2" {
  name                = var.hub1.spoke2_vnet_name
  resource_group_name = var.hub1.resource_group_name
}
data "azurerm_firewall" "hub1" {
  name                = var.hub1.azfw_name
  resource_group_name = var.hub1.resource_group_name
}

# Add route to hub2 AzFW subnet
resource "azurerm_route" "toHub1Spoke1" {
  name                   = "toHub1Spoke1"
  resource_group_name    = var.rg.name
  route_table_name       = module.hub2.hub_route_table_name
  address_prefix         = data.azurerm_virtual_network.hub1spoke1.address_space[0]
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = data.azurerm_firewall.hub1.ip_configuration[0].private_ip_address
}
resource "azurerm_route" "toHub1Spoke2" {
  name                   = "toHub1Spoke2"
  resource_group_name    = var.rg.name
  route_table_name       = module.hub2.hub_route_table_name
  address_prefix         = data.azurerm_virtual_network.hub1spoke2.address_space[0]
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = data.azurerm_firewall.hub1.ip_configuration[0].private_ip_address
}

# Add route to hub1 AzFW subnet
data "azurerm_route_table" "hub1azfw" {
  name                = var.hub1.azfw_route_table_name
  resource_group_name = var.hub1.resource_group_name
}
resource "azurerm_route" "toHub2Spoke1" {
  name                   = "toHub2Spoke1"
  resource_group_name    = var.hub1.resource_group_name
  route_table_name       = data.azurerm_route_table.hub1azfw.name
  address_prefix         = var.spoke_vnet1.base_cidr_block
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = data.azurerm_firewall.hub2.ip_configuration[0].private_ip_address
}
resource "azurerm_route" "toHub2Spoke2" {
  name                   = "toHub2Spoke2"
  resource_group_name    = var.hub1.resource_group_name
  route_table_name       = data.azurerm_route_table.hub1azfw.name
  address_prefix         = var.spoke_vnet2.base_cidr_block
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = data.azurerm_firewall.hub2.ip_configuration[0].private_ip_address
}

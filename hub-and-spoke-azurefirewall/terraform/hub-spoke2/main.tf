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

data "http" "my_public_ip" {
  url = "https://ipconfig.io"
}

resource "azurerm_resource_group" "hub" {
  name     = var.rg.name
  location = var.rg.location
}

resource "azurerm_log_analytics_workspace" "hub2" {
  name                = "la-hub2"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  retention_in_days   = 30
}

data "azurerm_monitor_diagnostic_categories" "azfw-diag-categories" {
  resource_id = module.azfw.id
}

module "diag-azfw" {
  source                     = "../modules/diagnostic_logs"
  name                       = "diag"
  target_resource_id         = module.azfw.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub2.id
  diagnostic_logs            = data.azurerm_monitor_diagnostic_categories.azfw-diag-categories.logs
  retention                  = 30
}

// ------------------------------------------
// Hub
// ------------------------------------------
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub2"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  address_space       = [module.hub_vnet_subnet_addrs.base_cidr_block]
}

module "hub_vnet_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.hub_vnet.base_cidr_block
  networks = [
    {
      name     = "default"
      new_bits = 8
    },
    {
      name     = "vpngw",
      new_bits = 8
    },
    {
      name     = "azfw",
      new_bits = 8
    },
    {
      name     = "bastion",
      new_bits = 8
    },
  ]
}

resource "azurerm_subnet" "hub_default" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [module.hub_vnet_subnet_addrs.network_cidr_blocks["default"]]
}

resource "azurerm_subnet" "hub_vpngw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.hub_default,
  ]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [module.hub_vnet_subnet_addrs.network_cidr_blocks["vpngw"]]
}
resource "azurerm_subnet" "hub_azfw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.hub_vpngw,
  ]
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [module.hub_vnet_subnet_addrs.network_cidr_blocks["azfw"]]
}
resource "azurerm_subnet" "hub_bastion" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.hub_azfw,
  ]
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [module.hub_vnet_subnet_addrs.network_cidr_blocks["bastion"]]
}

module "azfw" {
  source = "../modules/azurefirewall-premium"
  rg = {
    name     = azurerm_resource_group.hub.name
    location = azurerm_resource_group.hub.location
  }
  id        = "hub2"
  subnet_id = azurerm_subnet.hub_azfw.id
}

resource "azurerm_route_table" "hubAzFW" {
  name                          = "rt-hub-azfw"
  resource_group_name           = azurerm_resource_group.hub.name
  location                      = azurerm_resource_group.hub.location
  disable_bgp_route_propagation = false

  /* Separate additional route */
}

resource "azurerm_subnet_route_table_association" "hubAzFW" {
  subnet_id      = azurerm_subnet.hub_azfw.id
  route_table_id = azurerm_route_table.hubAzFW.id
}

module "bastion" {
  source              = "../modules/bastion"
  name                = "bastion-hub2"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  subnet_id           = azurerm_subnet.hub_bastion.id

}
// ------------------------------------------
// Spoke 1
// ------------------------------------------
resource "azurerm_virtual_network" "spoke1" {
  name                = "vnet-hub2-spoke1"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  address_space       = [var.spoke_vnet1.base_cidr_block]
}

resource "azurerm_subnet" "spoke1_default" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.spoke1.name
  address_prefixes     = [var.spoke_vnet1.base_cidr_block]
}

resource "azurerm_route_table" "spoke1default" {
  name                          = "rt-spoke1-default"
  resource_group_name           = azurerm_resource_group.hub.name
  location                      = azurerm_resource_group.hub.location
  disable_bgp_route_propagation = false

  route = [{
    name                   = "default"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = module.azfw.private_ip_address
  }]
}

resource "azurerm_subnet_route_table_association" "spoke1default" {
  subnet_id      = azurerm_subnet.spoke1_default.id
  route_table_id = azurerm_route_table.spoke1default.id
}

resource "azurerm_network_security_group" "spoke1" {
  name                = "nsg-spoke1"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
}

resource "azurerm_subnet_network_security_group_association" "spoke1" {
  subnet_id                 = azurerm_subnet.spoke1_default.id
  network_security_group_id = azurerm_network_security_group.spoke1.id
}

module "vm-spoke1" {
  source              = "../modules/vm-linux"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  name                = "vm-hub2-spoke1"
  zone                = "1"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  subnet_id           = azurerm_subnet.spoke1_default.id
}

// ------------------------------------------
// Spoke 2
// ------------------------------------------
resource "azurerm_virtual_network" "spoke2" {
  name                = "vnet-hub2-spoke2"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  address_space       = [var.spoke_vnet2.base_cidr_block]
}

resource "azurerm_subnet" "spoke2_default" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.spoke2.name
  address_prefixes     = [var.spoke_vnet2.base_cidr_block]
}

resource "azurerm_route_table" "spoke2default" {
  name                          = "rt-spoke2-default"
  resource_group_name           = azurerm_resource_group.hub.name
  location                      = azurerm_resource_group.hub.location
  disable_bgp_route_propagation = false

  route = [{
    name                   = "default"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = module.azfw.private_ip_address
  }]
}

resource "azurerm_subnet_route_table_association" "spoke2default" {
  subnet_id      = azurerm_subnet.spoke2_default.id
  route_table_id = azurerm_route_table.spoke2default.id
}

resource "azurerm_network_security_group" "spoke2" {
  name                = "nsg-spoke2"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
}

resource "azurerm_subnet_network_security_group_association" "spoke2" {
  subnet_id                 = azurerm_subnet.spoke2_default.id
  network_security_group_id = azurerm_network_security_group.spoke2.id
}

module "vm-spoke2" {
  source              = "../modules/vm-linux"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  name                = "vm-hub2-spoke2"
  zone                = "1"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  subnet_id           = azurerm_subnet.spoke2_default.id
}


// ------------------------------------------
// Peering
// ------------------------------------------
resource "azurerm_virtual_network_peering" "spoke1tohub" {
  name                      = "Spoke1ToHub"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.spoke1.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}
resource "azurerm_virtual_network_peering" "hubtospoke1" {
  name                      = "HubToSpoke1"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke1.id
}
resource "azurerm_virtual_network_peering" "spoke2tohub" {
  name                      = "Spoke2ToHub"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.spoke2.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}
resource "azurerm_virtual_network_peering" "hubtospoke2" {
  name                      = "HubToSpoke2"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke2.id
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
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_gateway_transit     = true
  use_remote_gateways       = false
  allow_forwarded_traffic   = true
}
resource "azurerm_virtual_network_peering" "hub2Tohub1" {
  name                      = "Hub2ToHub1"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub.name
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
resource "azurerm_route" "default" {
  name                = "default"
  resource_group_name = azurerm_resource_group.hub.name
  route_table_name    = azurerm_route_table.hubAzFW.name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "Internet"
}
resource "azurerm_route" "toHub1Spoke1" {
  name                   = "toHub1Spoke1"
  resource_group_name    = azurerm_resource_group.hub.name
  route_table_name       = azurerm_route_table.hubAzFW.name
  address_prefix         = data.azurerm_virtual_network.hub1spoke1.address_space[0]
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = data.azurerm_firewall.hub1.ip_configuration[0].private_ip_address
}
resource "azurerm_route" "toHub1Spoke2" {
  name                   = "toHub1Spoke2"
  resource_group_name    = azurerm_resource_group.hub.name
  route_table_name       = azurerm_route_table.hubAzFW.name
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
  address_prefix         = azurerm_virtual_network.spoke1.address_space[0]
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = module.azfw.private_ip_address
}
resource "azurerm_route" "toHub2Spoke2" {
  name                   = "toHub2Spoke2"
  resource_group_name    = var.hub1.resource_group_name
  route_table_name       = data.azurerm_route_table.hub1azfw.name
  address_prefix         = azurerm_virtual_network.spoke2.address_space[0]
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = module.azfw.private_ip_address
}

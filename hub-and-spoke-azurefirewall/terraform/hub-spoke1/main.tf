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

resource "azurerm_log_analytics_workspace" "hub1" {
  name                = "la-hub1"
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
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub1.id
  diagnostic_logs            = data.azurerm_monitor_diagnostic_categories.azfw-diag-categories.logs
  retention                  = 30
}

// ------------------------------------------
// On-prem
// ------------------------------------------

resource "azurerm_virtual_network" "onprem" {
  name                = "vnet-onprem"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  address_space       = [module.onprem_vnet_subnet_addrs.base_cidr_block]
}

module "onprem_vnet_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.onprem_vnet.base_cidr_block
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
      name     = "bastion",
      new_bits = 8
    },
  ]
}

resource "azurerm_subnet" "onprem_default" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = [module.onprem_vnet_subnet_addrs.network_cidr_blocks["default"]]
}

resource "azurerm_subnet" "onprem_vpngw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.onprem_default,
  ]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = [module.onprem_vnet_subnet_addrs.network_cidr_blocks["vpngw"]]
}
resource "azurerm_subnet" "onprem_bastion" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.onprem_vpngw
  ]
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = [module.onprem_vnet_subnet_addrs.network_cidr_blocks["bastion"]]
}

module "bastion_onprem" {
  source              = "../modules/bastion"
  name                = "bastion-onprem"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  subnet_id           = azurerm_subnet.onprem_bastion.id
}

module "vm-onprem1" {
  source              = "../modules/vm-linux"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  name                = "vm-hub1-onprem1"
  zone                = "1"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  subnet_id           = azurerm_subnet.onprem_default.id
}

module "vpngw_onprem" {
  count = var.deploy_onprem_environment ? 1 : 0

  source = "../modules/vpngateway"
  name   = "vpng-onprem"
  rg = {
    name     = azurerm_resource_group.hub.name
    location = azurerm_resource_group.hub.location
  }
  subnet_id = azurerm_subnet.onprem_vpngw.id

  bgp = {
    asn = 65516
  }

}

resource "azurerm_virtual_network_gateway_connection" "onprem_to_hub1" {
  count = var.deploy_onprem_environment ? 1 : 0

  name                = "onprem-to-hub1"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = module.vpngw_onprem[0].virtual_network_gateway_id
  peer_virtual_network_gateway_id = module.vpngw[0].virtual_network_gateway_id

  enable_bgp = true

  shared_key = "4-v3ry-53cr37-1p53c-5h4r3d-k3y"
}

resource "azurerm_virtual_network_gateway_connection" "hub1_to_onprem" {
  count = var.deploy_onprem_environment ? 1 : 0

  name                = "hub1-to-onprem"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = module.vpngw[0].virtual_network_gateway_id
  peer_virtual_network_gateway_id = module.vpngw_onprem[0].virtual_network_gateway_id

  enable_bgp = true

  shared_key = "4-v3ry-53cr37-1p53c-5h4r3d-k3y"
}

// ------------------------------------------
// Hub
// ------------------------------------------
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub1"
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
  id        = "hub1"
  subnet_id = azurerm_subnet.hub_azfw.id
}

resource "azurerm_route_table" "hubAzFW" {
  name                          = "rt-hub-azfw"
  resource_group_name           = azurerm_resource_group.hub.name
  location                      = azurerm_resource_group.hub.location
  disable_bgp_route_propagation = false

  lifecycle {
    ignore_changes = [
      route
    ]
  }

  route = [
    {
      name                   = "default"
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "Internet"
      next_hop_in_ip_address = null
    }
  ]
}

resource "azurerm_subnet_route_table_association" "hubAzFW" {
  subnet_id      = azurerm_subnet.hub_azfw.id
  route_table_id = azurerm_route_table.hubAzFW.id
}

module "bastion" {
  source              = "../modules/bastion"
  name                = "bastion-hub1"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  subnet_id           = azurerm_subnet.hub_bastion.id

}
module "vpngw" {
  count = var.deploy_onprem_environment ? 1 : 0

  source = "../modules/vpngateway"
  name   = "vpng-hub1"
  rg = {
    name     = azurerm_resource_group.hub.name
    location = azurerm_resource_group.hub.location
  }
  subnet_id = azurerm_subnet.hub_vpngw.id

  bgp = {
    asn = 65515
  }
}
// ------------------------------------------
// Spoke 1
// ------------------------------------------
resource "azurerm_virtual_network" "spoke1" {
  name                = "vnet-hub1-spoke1"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  address_space       = [module.spoke1_vnet_subnet_addrs.base_cidr_block]
}

module "spoke1_vnet_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.spoke_vnet1.base_cidr_block
  networks = [
    {
      name     = "default"
      new_bits = 8
    },
  ]
}

resource "azurerm_subnet" "spoke1_default" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.spoke1.name
  address_prefixes     = [module.spoke1_vnet_subnet_addrs.network_cidr_blocks["default"]]
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
  name                = "vm-hub1-spoke1"
  zone                = "1"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  subnet_id           = azurerm_subnet.spoke1_default.id
}

// ------------------------------------------
// Spoke 2
// ------------------------------------------
resource "azurerm_virtual_network" "spoke2" {
  name                = "vnet-hub1-spoke2"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  address_space       = [module.spoke2_vnet_subnet_addrs.base_cidr_block]
}

module "spoke2_vnet_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.spoke_vnet2.base_cidr_block
  networks = [
    {
      name     = "default"
      new_bits = 8
    },
  ]
}

resource "azurerm_subnet" "spoke2_default" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.spoke2.name
  address_prefixes     = [module.spoke2_vnet_subnet_addrs.network_cidr_blocks["default"]]
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
  name                = "vm-hub1-spoke2"
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

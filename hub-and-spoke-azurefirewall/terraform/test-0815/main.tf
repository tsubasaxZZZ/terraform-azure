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

module "hub1" {
  source         = "../"
  rg             = var.rg
  admin_username = var.admin_username
  admin_password = var.admin_password

  environment_name = var.environment_name

  onprem_vnet = var.onprem_vnet
  hub_vnet    = var.hub_vnet
  spoke_vnet1 = var.spoke_vnet1
  spoke_vnet2 = var.spoke_vnet2
}

resource "azurerm_subnet" "hub_dmz" {
  name                 = "snet-DMZ"
  resource_group_name  = var.rg.name
  virtual_network_name = module.hub1.hub_vnet_name
  address_prefixes     = [var.hub_vnet.subnet_dmz_cidr]
}

resource "azurerm_subnet" "spoke2_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.rg.name
  virtual_network_name = module.hub1.spoke2_vnet_name
  address_prefixes     = [var.spoke_vnet2.subnet_gateway_cidr]
}

data "azurerm_firewall" "hub" {
  depends_on = [
    module.hub1
  ]
  name                = module.hub1.azfw_name
  resource_group_name = var.rg.name
}

data "azurerm_subnet" "gateway" {
  depends_on = [
    module.hub1,
  ]
  name                 = "GatewaySubnet"
  resource_group_name  = var.rg.name
  virtual_network_name = module.hub1.hub_vnet_name
}

module "onprem" {
  depends_on = [
    module.hub1
  ]

  count  = var.deploy_onprem_environment ? 1 : 0
  source = "./onprem"

  environment_name = var.environment_name

  rg                      = var.rg
  admin_username          = var.admin_username
  admin_password          = var.admin_password
  onprem_vnet             = var.onprem_vnet
  azfw_private_ip_address = data.azurerm_firewall.hub.ip_configuration[0].private_ip_address
  hub_vnet_gw_subnet_id   = data.azurerm_subnet.gateway.id
  hub_vnet                = var.hub_vnet
  spoke_vnet1             = var.spoke_vnet1
  spoke_vnet2             = var.spoke_vnet2
}

module "branch" {
  depends_on = [
    module.hub1
  ]

  count  = var.deploy_branch_environment ? 1 : 0
  source = "./branch"

  environment_name = "spoke2"

  rg                       = var.rg
  admin_username           = var.admin_username
  admin_password           = var.admin_password
  branch_vnet              = var.branch_vnet
  spoke2_vnet_gw_subnet_id = azurerm_subnet.spoke2_gateway.id
  spoke_vnet2              = var.spoke_vnet2
}

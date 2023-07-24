terraform {
  required_version = "~> 1.3.0"

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

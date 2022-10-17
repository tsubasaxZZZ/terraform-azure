terraform {
  required_version = "~> 1.2.1"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
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

resource "azurerm_resource_group" "example" {
  name     = var.rg.name
  location = var.rg.location
}

resource "random_string" "uniqstr" {
  length  = 6
  special = false
  upper   = false
  keepers = {
    resource_group_name = var.rg.name
  }
}

module "la" {
  source              = "../modules/log_analytics"
  name                = "la-${random_string.uniqstr.result}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
}

// ------------------------------------------
// VNet
// ------------------------------------------
resource "azurerm_virtual_network" "east" {
  name                = "vnet-east"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_east.location
  address_space       = [module.azure_east_subnet_addrs.base_cidr_block]
}

module "azure_east_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.azure_east.base_cidr_block
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
    {
      name     = "routeserver",
      new_bits = 8
    },
  ]
}
resource "azurerm_subnet" "east_default" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.east.name
  address_prefixes     = [module.azure_east_subnet_addrs.network_cidr_blocks["default"]]
}

resource "azurerm_subnet" "east_bastion" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.east_default,
  ]
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.east.name
  address_prefixes     = [module.azure_east_subnet_addrs.network_cidr_blocks["bastion"]]
}

resource "azurerm_subnet" "east_vpngw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.east_bastion,
  ]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.east.name
  address_prefixes     = [module.azure_east_subnet_addrs.network_cidr_blocks["vpngw"]]
}

resource "azurerm_subnet" "east_routeserver" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.east_vpngw,
  ]
  name                 = "RouteServerSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.east.name
  address_prefixes     = [module.azure_east_subnet_addrs.network_cidr_blocks["routeserver"]]
}

resource "azurerm_virtual_network" "west" {
  name                = "vnet-west"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_west.location
  address_space       = [module.azure_west_subnet_addrs.base_cidr_block]
}
module "azure_west_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.azure_west.base_cidr_block
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
    {
      name     = "routeserver",
      new_bits = 8
    },
  ]
}

resource "azurerm_subnet" "west_default" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.west.name
  address_prefixes     = [module.azure_west_subnet_addrs.network_cidr_blocks["default"]]
}

resource "azurerm_subnet" "west_bastion" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.west_default,
  ]
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.west.name
  address_prefixes     = [module.azure_west_subnet_addrs.network_cidr_blocks["bastion"]]
}

resource "azurerm_subnet" "west_vpngw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.west_bastion,
  ]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.west.name
  address_prefixes     = [module.azure_west_subnet_addrs.network_cidr_blocks["vpngw"]]
}
resource "azurerm_subnet" "west_routeserver" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.west_vpngw,
  ]
  name                 = "RouteServerSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.west.name
  address_prefixes     = [module.azure_west_subnet_addrs.network_cidr_blocks["routeserver"]]
}

// --- Azure Bastion ---
module "bastion_east" {
  source              = "../modules/bastion/"
  name                = "bastion-east"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_east.location
  subnet_id           = azurerm_subnet.east_bastion.id
}

module "bastion_west" {
  source              = "../modules/bastion/"
  name                = "bastion-west"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_west.location
  subnet_id           = azurerm_subnet.west_bastion.id
}

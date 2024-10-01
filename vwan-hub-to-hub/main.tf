terraform {
  required_version = "~> 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
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

resource "azurerm_virtual_wan" "example" {
  name                = "vwan-east"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  # Configuration 
  office365_local_breakout_category = "OptimizeAndAllow"

}
# Virtual WAN Hubs

//////////////////////////////
# Japan East
//////////////////////////////

resource "azurerm_virtual_hub" "east" {
  name                = "vhub-east"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_east.location
  virtual_wan_id      = azurerm_virtual_wan.example.id
  address_prefix      = var.azure_east.vwan_address_prefix
}

resource "azurerm_express_route_gateway" "east" {
  count = var.azure_east.deploy_er_gateway ? 1 : 0

  name                = "erg-east"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_virtual_hub.east.location
  virtual_hub_id      = azurerm_virtual_hub.east.id
  scale_units         = 1
}
//////////////////////////////
# Japan West
//////////////////////////////
resource "azurerm_virtual_hub" "west" {
  name                = "vhub-west"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_west.location
  virtual_wan_id      = azurerm_virtual_wan.example.id
  address_prefix      = var.azure_west.vwan_address_prefix
}

resource "azurerm_vpn_gateway" "west" {
  count               = var.azure_west.deploy_vpn_gateway ? 1 : 0
  name                = "vpngw-west"
  location            = azurerm_virtual_hub.west.location
  resource_group_name = azurerm_resource_group.example.name
  virtual_hub_id      = azurerm_virtual_hub.west.id
}

//////////////////////////////

resource "azurerm_virtual_hub_connection" "east" {
  name                      = "vhub-conn-east-west"
  virtual_hub_id            = azurerm_virtual_hub.east.id
  remote_virtual_network_id = azurerm_virtual_network.east.id
  internet_security_enabled = true
}

resource "azurerm_virtual_hub_connection" "west" {
  name                      = "vhub-conn-west-east"
  virtual_hub_id            = azurerm_virtual_hub.west.id
  remote_virtual_network_id = azurerm_virtual_network.west.id
  internet_security_enabled = true
}

resource "azurerm_virtual_hub_connection" "west_east_shared" {
  name                      = "vhub-conn-west-east_shared"
  virtual_hub_id            = azurerm_virtual_hub.west.id
  remote_virtual_network_id = azurerm_virtual_network.east_shared.id
  internet_security_enabled = true
}

module "securevwan_east" {
  count               = var.enable_secure_vwan ? 1 : 0
  source              = "./securevwan"
  log_analytics_id    = module.la.id
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_east.location
  id                  = "east"
  virtual_hub_id      = azurerm_virtual_hub.east.id
}

module "securevwan_west" {
  count               = var.enable_secure_vwan ? 1 : 0
  source              = "./securevwan"
  log_analytics_id    = module.la.id
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_west.location
  id                  = "west"
  virtual_hub_id      = azurerm_virtual_hub.west.id
}

resource "azurerm_virtual_hub_routing_intent" "example" {
  name           = "hubRoutingIntent"
  virtual_hub_id = azurerm_virtual_hub.east.id

  routing_policy {
    name         = "PublicTraffic"
    destinations = ["Internet"]
    next_hop     = module.securevwan_east[0].id
  }

  routing_policy {
    name         = "PrivateTraffic"
    destinations = ["PrivateTraffic"]
    next_hop     = module.securevwan_east[0].id
  }
}


# resource "azurerm_virtual_hub_route_table" "default" {
#   name           = "defaultRouteTable"
#   virtual_hub_id = azurerm_virtual_hub.east.id
#   labels         = ["default"]

#   route {
#     name              = "_policy_InternetTrafficPolicy"
#     destinations_type = "CIDR"
#     destinations      = ["0.0.0.0/0"]
#     next_hop_type     = "ResourceId"
#     next_hop          = module.securevwan_east[0].id
#   }
# }

# resource "azurerm_virtual_hub_route_table" "none" {
#   name           = "noneRouteTable"
#   virtual_hub_id = azurerm_virtual_hub.east.id
#   labels         = ["none"]
# }

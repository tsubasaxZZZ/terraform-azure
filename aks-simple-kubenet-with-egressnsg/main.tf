terraform {
  required_version = "~> 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.63.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "random_string" "uniqstr" {
  length  = 6
  special = false
  upper   = false
  keepers = {
    resource_group_name = var.resource_group_name
  }
}
resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name
  location = var.location
}
resource "azurerm_container_registry" "acr" {
  name                = "acrtsunomuraksdemo${random_string.uniqstr.result}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  sku                 = "Basic"
  admin_enabled       = false
  //georeplication_locations = false
}

module "la" {
  source              = "../modules/log_analytics"
  name                = "la-aksdemo${random_string.uniqstr.result}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = null
  retention           = null
}
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-aksdemo"
  address_space       = ["10.14.0.0/16"]
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
}

resource "azurerm_subnet" "subnet-default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.14.100.0/24"]
}
resource "azurerm_subnet" "subnet-aks" {
  name                 = "aks"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.14.10.0/24"]
}
module "demo-aks" {
  source                     = "../modules/aks-kubenet"
  name                       = "aksdemo${random_string.uniqstr.result}"
  resource_group_name        = azurerm_resource_group.example.name
  location                   = azurerm_resource_group.example.location
  container_registry_id      = azurerm_container_registry.acr.id
  log_analytics_workspace_id = module.la.id
  kubernetes_version         = var.aks_version
  private_cluster            = false
  default_node_pool = {
    name                           = "nodepool"
    node_count                     = 5
    vm_size                        = "Standard_B2s"
    zones                          = ["1", "2", "3"]
    labels                         = null
    taints                         = null
    cluster_auto_scaling           = false
    cluster_auto_scaling_max_count = null
    cluster_auto_scaling_min_count = null
  }
  addons = {
    oms_agent            = true
    kubernetes_dashboard = false
    azure_policy         = false
  }
  vnet_subnet_id        = azurerm_subnet.subnet-aks.id
  sla_sku               = null
  api_auth_ips          = null
  additional_node_pools = {}
  aad_group_name        = null
  ssh_key               = file(var.aks_worker_ssh_key_path)
  admin_username        = var.aks_worker_admin_username
}

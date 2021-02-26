terraform {
  required_version = "~> 0.14.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.46.1"
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
  address_space       = ["10.0.0.0/8"]
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
}

resource "azurerm_subnet" "subnet-default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}
resource "azurerm_subnet" "subnet-aks" {
  name                 = "aks"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

###################
# VM
###################
data "azurerm_ssh_public_key" "example" {
  name                = var.ssh_public_key_name
  resource_group_name = var.ssh_public_key_resource_group
}
module "linux-vm" {
  source              = "../modules/vm-linux"
  admin_username      = "tsunomur"
  public_key          = file(var.ssh_key_path)
  name                = "vm-jumpbox"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.subnet-default.id
  zone                = 1
  custom_data         = <<EOF
#!/bin/bash
sudo apt-get update
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
EOF
}

/*
module "windows-vm" {
  source              = "./modules/virtualmachine/windows"
  admin_username      = "adminuser"
  admin_password      = "pn,i86*3+R"
  name                = "VM1"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.subnet-default.id
  zone                = 1
}
*/


###################
# AKS
###################
module "demo-aks" {
  source                     = "../modules/aks"
  name                       = "aksdemo${random_string.uniqstr.result}"
  resource_group_name        = azurerm_resource_group.example.name
  location                   = azurerm_resource_group.example.location
  container_registry_id      = azurerm_container_registry.acr.id
  log_analytics_workspace_id = module.la.id
  kubernetes_version         = var.aks_version
  private_cluster            = false
  default_node_pool = {
    name                           = "nodepool"
    node_count                     = 1
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

data "azurerm_monitor_diagnostic_categories" "aks-diag-categories" {
  resource_id = module.demo-aks.id
}

module "diag-aks" {
  source                     = "../modules/diagnostic_logs"
  name                       = "diag"
  target_resource_id         = module.demo-aks.id
  log_analytics_workspace_id = module.la.id
  diagnostic_logs            = data.azurerm_monitor_diagnostic_categories.aks-diag-categories.logs
  retention                  = 30
}

resource "azurerm_storage_account" "storage" {
  name                      = "sa${random_string.uniqstr.result}"
  resource_group_name       = azurerm_resource_group.example.name
  location                  = azurerm_resource_group.example.location
  account_kind              = "StorageV2"
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  access_tier               = "Hot"
  enable_https_traffic_only = true
}

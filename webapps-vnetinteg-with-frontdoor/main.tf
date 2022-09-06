terraform {
  required_version = "~> 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
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
    resource_group_name = var.rg.name
  }
}

resource "azurerm_resource_group" "example" {
  name     = var.rg.name
  location = var.rg.location
}

# --------------------------
# Log Analytics
# --------------------------
module "la" {
  source              = "../modules/log_analytics"
  name                = "la-${random_string.uniqstr.result}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
}

# --------------------------
# Web App (Linux)
# --------------------------
resource "azurerm_service_plan" "example" {
  name                = "plan-${random_string.uniqstr.result}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  os_type             = "Linux"
  sku_name            = "S1"
}

resource "azurerm_service_plan" "azfw" {
  name                = "plan-${random_string.uniqstr.result}-azfw"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  os_type             = "Linux"
  sku_name            = "S1"
}

resource "azurerm_service_plan" "natgw" {
  name                = "plan-${random_string.uniqstr.result}-natgw"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  os_type             = "Linux"
  sku_name            = "S1"
}

// Custom container
resource "azurerm_linux_web_app" "app1" {
  name                      = "app-${random_string.uniqstr.result}-1"
  resource_group_name       = azurerm_resource_group.example.name
  location                  = azurerm_service_plan.example.location
  service_plan_id           = azurerm_service_plan.example.id
  virtual_network_subnet_id = azurerm_subnet.appservice.id

  site_config {
    application_stack {
      docker_image     = "tsubasaxzzz/nginx-0829"
      docker_image_tag = "app1"
    }
  }
}

// Backend of Front Door
resource "azurerm_linux_web_app" "app2" {
  name                      = "app-${random_string.uniqstr.result}-2"
  resource_group_name       = azurerm_resource_group.example.name
  location                  = azurerm_service_plan.example.location
  service_plan_id           = azurerm_service_plan.example.id
  virtual_network_subnet_id = azurerm_subnet.appservice.id

  site_config {
    application_stack {
      node_version = "16-lts"
    }
  }
}

// Backend of Azure Firewall
resource "azurerm_linux_web_app" "app3" {
  name                      = "app-${random_string.uniqstr.result}-azfw"
  resource_group_name       = azurerm_resource_group.example.name
  location                  = azurerm_service_plan.example.location
  service_plan_id           = azurerm_service_plan.azfw.id
  virtual_network_subnet_id = azurerm_subnet.appservice_azfw.id

  site_config {
    application_stack {
      node_version = "16-lts"
    }
    vnet_route_all_enabled = true
  }
}
// Backend of NAT GW
resource "azurerm_linux_web_app" "app4" {
  name                      = "app-${random_string.uniqstr.result}-natgw"
  resource_group_name       = azurerm_resource_group.example.name
  location                  = azurerm_service_plan.example.location
  service_plan_id           = azurerm_service_plan.natgw.id
  virtual_network_subnet_id = azurerm_subnet.appservice_natgw.id

  site_config {
    application_stack {
      node_version = "16-lts"
    }
    vnet_route_all_enabled = true
  }
}


data "azurerm_monitor_diagnostic_categories" "app1_diag_category" {
  resource_id = azurerm_linux_web_app.app1.id
}

module "app1_diag" {
  source                     = "../modules/diagnostic_logs"
  name                       = "app1-diag"
  target_resource_id         = azurerm_linux_web_app.app1.id
  log_analytics_workspace_id = module.la.id
  diagnostic_logs            = data.azurerm_monitor_diagnostic_categories.app1_diag_category.logs
  retention                  = 30
}
module "app2_diag" {
  source                     = "../modules/diagnostic_logs"
  name                       = "app2-diag"
  target_resource_id         = azurerm_linux_web_app.app2.id
  log_analytics_workspace_id = module.la.id
  diagnostic_logs            = data.azurerm_monitor_diagnostic_categories.app1_diag_category.logs
  retention                  = 30
}
module "app3_diag" {
  source                     = "../modules/diagnostic_logs"
  name                       = "app3-diag"
  target_resource_id         = azurerm_linux_web_app.app3.id
  log_analytics_workspace_id = module.la.id
  diagnostic_logs            = data.azurerm_monitor_diagnostic_categories.app1_diag_category.logs
  retention                  = 30
}
module "app4_diag" {
  source                     = "../modules/diagnostic_logs"
  name                       = "app4-diag"
  target_resource_id         = azurerm_linux_web_app.app4.id
  log_analytics_workspace_id = module.la.id
  diagnostic_logs            = data.azurerm_monitor_diagnostic_categories.app1_diag_category.logs
  retention                  = 30
}
# --------------------------
# VNet
# --------------------------
resource "azurerm_virtual_network" "example" {
  name                = "vnet-webapps"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = ["10.254.0.0/16"]
}
resource "azurerm_subnet" "appservice" {
  name                 = "snet-appservice"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.254.0.0/24"]
  delegation {
    name = "example-delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}
resource "azurerm_subnet" "vm" {
  name                 = "snet-vm"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.254.1.0/24"]
  depends_on = [
    azurerm_subnet.appservice,
  ]
}
resource "azurerm_subnet" "appservice_azfw" {
  name                 = "snet-appservice-route-to-azfw"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.254.2.0/24"]
  depends_on = [
    azurerm_subnet.vm,
  ]
  delegation {
    name = "example-delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}
resource "azurerm_subnet" "appservice_natgw" {
  name                 = "snet-appservice-route-to-natgw"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.254.3.0/24"]
  depends_on = [
    azurerm_subnet.appservice_azfw,
  ]
  delegation {
    name = "example-delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}
resource "azurerm_subnet" "azfw" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.254.100.0/24"]
  depends_on = [
    azurerm_subnet.appservice_azfw,
  ]
}
# --------------------------
# VM
# --------------------------
module "jumpbox-linux" {
  source              = "../modules/vm-linux/"
  admin_username      = "adminuser"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "vmjumpboxlinux"
  subnet_id           = azurerm_subnet.vm.id
  public_key          = file("~/.ssh/id_rsa.pub")
  custom_data         = "test"
}
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.254.255.0/24"]
}

module "bastion" {
  source              = "../modules/bastion/"
  name                = "bastion"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.bastion.id
}

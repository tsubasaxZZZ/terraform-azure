terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.57.0"
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
    resource_group_name = var.resource_group1_name
  }
}

resource "azurerm_resource_group" "client" {
  name     = var.resource_group1_name
  location = var.resource_group1_location
}

resource "azurerm_resource_group" "resource" {
  name     = var.resource_group2_name
  location = var.resource_group2_location
}

locals {
  resource_prefix   = "${var.environment_name}-${azurerm_resource_group.resource.location}-${random_string.uniqstr.result}"
  resource_prefix2  = "${var.environment_name}${random_string.uniqstr.result}"
  function_app_name = "func-${local.resource_prefix}"
}

###################
# Event Hubs
###################
resource "azurerm_eventhub_namespace" "example" {
  name                     = "evhns-${local.resource_prefix}"
  location                 = azurerm_resource_group.resource.location
  resource_group_name      = azurerm_resource_group.resource.name
  sku                      = var.eventhubs_sku
  capacity                 = var.eventhubs_capacity
  auto_inflate_enabled     = var.eventhubs_auto_inflate_enabled
  maximum_throughput_units = var.eventhubs_maximum_throughput_units

  /*
  network_rulesets = [{
    default_action = "Deny"
    ip_rule = [{
      action  = "Allow"
      ip_mask = var.connection_from_ipaddress
    }]
    trusted_service_access_enabled = false
    virtual_network_rule           = []
  }]
*/
}

resource "azurerm_eventhub" "example" {
  name                = "evh-${local.resource_prefix}"
  namespace_name      = azurerm_eventhub_namespace.example.name
  resource_group_name = azurerm_resource_group.resource.name
  partition_count     = var.eventhubs_instance_partition_count
  message_retention   = var.eventhubs_instance_message_retention
}

###################
# Functions
###################
resource "azurerm_storage_account" "example" {
  name                     = "st${local.resource_prefix2}"
  resource_group_name      = azurerm_resource_group.resource.name
  location                 = azurerm_resource_group.resource.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "example" {
  name                = "plan-${local.resource_prefix}"
  location            = azurerm_resource_group.resource.location
  resource_group_name = azurerm_resource_group.resource.name
  kind                = "FunctionApp"
  reserved            = true

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "example" {
  name                       = local.function_app_name
  location                   = azurerm_resource_group.resource.location
  resource_group_name        = azurerm_resource_group.resource.name
  app_service_plan_id        = azurerm_app_service_plan.example.id
  storage_account_name       = azurerm_storage_account.example.name
  storage_account_access_key = azurerm_storage_account.example.primary_access_key
  os_type                    = "linux"
  version                    = "~3"
  app_settings = {
    FUNCTIONS_EXTENSION_VERSION = "~3"
    #WEBSITE_RUN_FROM_PACKAGE              = "1"
    FUNCTIONS_WORKER_RUNTIME              = "python"
    APPINSIGHTS_INSTRUMENTATIONKEY        = "${azurerm_application_insights.example.instrumentation_key}"
    APPLICATIONINSIGHTS_CONNECTION_STRING = "${azurerm_application_insights.example.connection_string}"
    SQL_SERVER                            = "${azurerm_sql_server.sqlserver.fully_qualified_domain_name}"
    SQL_DATABASE                          = "${azurerm_sql_database.sqldb.name}"
    SQL_USERNAME                          = "${var.sqldb_admin}"
    SQL_PASSWORD                          = "${var.sqldb_password}"
    EVENTHUB                              = "${azurerm_eventhub_namespace.example.default_primary_connection_string}"
    FUNCTIONS_WORKER_PROCESS_COUNT        = 10
    PYTHON_THREADPOOL_THREAD_COUNT        = 1
  }

  /*
  lifecycle {
    ignore_changes = [
      app_settings,
    ]
  }
  */
  site_config {
    linux_fx_version = "Python|3.8"
    ftps_state       = "Disabled"
  }
}

#################
# SQL Database
#################
resource "azurerm_sql_server" "sqlserver" {
  name                         = "sql-${local.resource_prefix}"
  resource_group_name          = azurerm_resource_group.resource.name
  location                     = azurerm_resource_group.resource.location
  version                      = "12.0"
  administrator_login          = var.sqldb_admin
  administrator_login_password = var.sqldb_password
}
resource "azurerm_sql_database" "sqldb" {
  name                             = "sqldb-${local.resource_prefix}"
  resource_group_name              = azurerm_resource_group.resource.name
  location                         = azurerm_resource_group.resource.location
  server_name                      = azurerm_sql_server.sqlserver.name
  edition                          = var.sqldb_edition
  requested_service_objective_name = var.sqldb_service
}

resource "azurerm_sql_firewall_rule" "frommicrosoft" {
  name                = "FirewallRule1"
  resource_group_name = azurerm_resource_group.resource.name
  server_name         = azurerm_sql_server.sqlserver.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}
resource "azurerm_sql_firewall_rule" "fromclient" {
  name                = "FirewallRule2"
  resource_group_name = azurerm_resource_group.resource.name
  server_name         = azurerm_sql_server.sqlserver.name
  start_ip_address    = var.connection_from_ipaddress
  end_ip_address      = var.connection_from_ipaddress
}

#################
# Log Analytics
#################
module "la" {
  source              = "../modules/log_analytics"
  name                = "log-${local.function_app_name}"
  resource_group_name = azurerm_resource_group.resource.name
  location            = azurerm_resource_group.resource.location
  sku                 = null
  retention           = null
}
resource "azurerm_application_insights" "example" {
  name                = "appi-${local.function_app_name}"
  location            = azurerm_resource_group.resource.location
  resource_group_name = azurerm_resource_group.resource.name
  application_type    = "web"

  # https://github.com/terraform-providers/terraform-provider-azurerm/issues/1303
  tags = {
    "hidden-link:${azurerm_resource_group.resource.id}/providers/Microsoft.Web/sites/${local.function_app_name}" = "Resource"
  }

}

###################
# VNet(Client)
###################
resource "azurerm_virtual_network" "client" {
  name                = "vnet-client"
  address_space       = ["10.0.0.0/8"]
  resource_group_name = azurerm_resource_group.client.name
  location            = azurerm_resource_group.client.location
}

resource "azurerm_subnet" "client_default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.client.name
  virtual_network_name = azurerm_virtual_network.client.name
  address_prefixes     = ["10.0.0.0/24"]
}

###################
# VM(Client)
###################
module "linux-vm" {
  count               = 3
  source              = "../modules/vm-linux"
  admin_username      = "tsunomur"
  public_key          = file(var.ssh_key_path)
  name                = "vm-client-${count.index + 1}"
  resource_group_name = azurerm_resource_group.client.name
  location            = azurerm_resource_group.client.location
  subnet_id           = azurerm_subnet.client_default.id
  zone                = null
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

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
  resource_group_name = var.rg.name
  location            = var.rg.location
}

module "azfw" {
  source    = "../modules/azurefirewall-premium"
  rg        = var.rg
  id        = var.id
  subnet_id = azurerm_subnet.azfw.id
  sku       = var.sku

  azurefirewall_application_rule = [{
    name     = "AllowApplicationRuleCollection"
    priority = 2000
    action   = "Allow"
    rule = [
      {
        name                  = "All"
        destination_addresses = []
        destination_fqdn_tags = []
        destination_fqdns     = ["*"]
        destination_urls      = []
        protocols = [
          {
            port = 80
            type = "Http"
          },
          {
            port = 443
            type = "Https"
          }
        ]
        source_addresses = ["*"]
        source_ip_groups = []
        terminate_tls    = false
        web_categories   = []
      }
    ]
  }]

  azurefirewall_network_rule = [{
    action   = "Allow"
    name     = "AllowNetworkRuleCollection"
    priority = 1000
    rule = [
      {
        name                  = "All"
        source_addresses      = [var.source_ip_range]
        protocols             = ["TCP"]
        destination_ports     = ["*"]
        destination_addresses = ["*"]
        destination_fqdns     = []

      },
    ]
  }]
}

resource "azurerm_route_table" "vm" {
  name                          = "rt-vm"
  resource_group_name           = var.rg.name
  location                      = var.rg.location
  disable_bgp_route_propagation = false

  route = [{
    name                   = "default"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = module.azfw.private_ip_address
    },
    {
      name                   = "backend"
      address_prefix         = "10.254.2.0/24"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = module.azfw.private_ip_address

    }
  ]
}
resource "azurerm_subnet_route_table_association" "appservice" {
  subnet_id      = azurerm_subnet.vm.id
  route_table_id = azurerm_route_table.vm.id
}
data "azurerm_monitor_diagnostic_categories" "azfw_diag_category" {
  resource_id = module.azfw.id
}

module "afw_diag" {
  source                     = "../modules/diagnostic_logs"
  name                       = "diag"
  target_resource_id         = module.azfw.id
  log_analytics_workspace_id = module.la.id
  diagnostic_logs            = data.azurerm_monitor_diagnostic_categories.azfw_diag_category.logs
  retention                  = 30
}

# --------------------------
# VNet
# --------------------------
resource "azurerm_virtual_network" "example" {
  name                = "vnet-azfwprem"
  resource_group_name = var.rg.name
  location            = var.rg.location
  address_space       = ["10.254.0.0/16"]
}
resource "azurerm_subnet" "vm" {
  name                 = "snet-vm"
  resource_group_name  = var.rg.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.254.1.0/24"]
}
resource "azurerm_subnet" "azfw" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.rg.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.254.100.0/24"]
  depends_on = [
    azurerm_subnet.vm,
  ]
}
resource "azurerm_subnet" "pe" {
  name                 = "snet-pe"
  resource_group_name  = var.rg.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.254.2.0/24"]
  depends_on = [
    azurerm_subnet.vm,
  ]
}
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.rg.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.254.255.0/24"]
  depends_on = [
    azurerm_subnet.azfw,
  ]
}
resource "azurerm_private_endpoint" "example" {
  name                = "pe-to-backend"
  resource_group_name = var.rg.name
  location            = var.rg.location
  subnet_id           = azurerm_subnet.pe.id

  private_service_connection {
    name                           = "example-privateserviceconnection"
    private_connection_resource_id = azurerm_private_link_service.example.id
    is_manual_connection           = false
  }
}
# --------------------------
# VM
# --------------------------
module "webserver" {
  source              = "../modules/vm-linux/"
  admin_username      = "azureuser"
  public_key          = var.ssh_public_key
  resource_group_name = var.rg.name
  location            = var.rg.location
  subnet_id           = azurerm_subnet.vm.id
  name                = "vmwebserver"
  custom_data         = <<-EOF
  #cloud-config
    package_upgrade: true
    packages:
      - nginx
  EOF
}
module "bastion" {
  source              = "../modules/bastion/"
  name                = "bastion"
  resource_group_name = var.rg.name
  location            = var.rg.location
  subnet_id           = azurerm_subnet.bastion.id
}

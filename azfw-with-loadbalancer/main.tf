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

module "azure_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.base_cidr_block
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
    {
      name     = "azfw",
      new_bits = 8
    }
  ]
}

// ----------------------
// Virtual Network
// ----------------------
resource "azurerm_virtual_network" "example" {
  name                = "vnet-example"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = [module.azure_subnet_addrs.base_cidr_block]
}
resource "azurerm_subnet" "default" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = [module.azure_subnet_addrs.network_cidr_blocks["default"]]
}

resource "azurerm_subnet" "bastion" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.default,
  ]
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = [module.azure_subnet_addrs.network_cidr_blocks["bastion"]]
}

resource "azurerm_subnet" "vpngw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.vpngw,
  ]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = [module.azure_subnet_addrs.network_cidr_blocks["vpngw"]]
}

resource "azurerm_subnet" "azfw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.azfw,
  ]
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = [module.azure_subnet_addrs.network_cidr_blocks["azfw"]]
}
// ----------------------
// Azure Firewall
// ----------------------
module "azfw" {
  source = "../modules/azurefirewall-premium"
  rg = {
    name     = azurerm_resource_group.example.name
    location = azurerm_resource_group.example.location
  }
  id        = "example"
  subnet_id = azurerm_subnet.azfw.id
}
resource "azurerm_route_table" "default" {
  name                          = "rt-default"
  resource_group_name           = azurerm_resource_group.example.name
  location                      = azurerm_resource_group.example.location
  disable_bgp_route_propagation = false

  route = [
    {
      name                   = "default"
      address_prefix         =  module.onprem_subnet_addrs.network_cidr_blocks["default"]
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = module.azfw.private_ip_address
    }
  ]
}

resource "azurerm_subnet_route_table_association" "default" {
  subnet_id      = azurerm_subnet.default.id
  route_table_id = azurerm_route_table.default.id
}

resource "azurerm_route_table" "onprem" {
  name                          = "rt-onprem-default"
  resource_group_name           = azurerm_resource_group.example.name
  location                      = azurerm_resource_group.example.location
  disable_bgp_route_propagation = false

  route = [
    {
      name                   = "azure"
      address_prefix         = module.azure_subnet_addrs.network_cidr_blocks["default"]
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = module.azfw.private_ip_address
    }
  ]
}

resource "azurerm_subnet_route_table_association" "onprem" {
  subnet_id      = azurerm_subnet.default_onprem.id
  route_table_id = azurerm_route_table.onprem.id
}

data "azurerm_monitor_diagnostic_categories" "azfw-diag-categories" {
  resource_id = module.azfw.id
}

module "diag-azfw" {
  source                     = "../modules/diagnostic_logs"
  name                       = "diag"
  target_resource_id         = module.azfw.id
  log_analytics_workspace_id = module.la.id
  diagnostic_logs            = data.azurerm_monitor_diagnostic_categories.azfw-diag-categories.logs
  retention                  = 30
}

// ----------------------
// VM
// ----------------------
locals {
  vm_count = 2
}
module "linuxvm" {
  source = "../modules/vm-linux"

  count = local.vm_count

  admin_username      = "azureuser"
  public_key          = var.ssh_public_key
  name                = "vmlinux-${count.index + 1}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.default.id
  custom_data         = <<EOF
#cloud-config
packages_update: true
packages_upgrade: true
packages:
  - nginx
EOF
}
// ----------------------
// Azure Bastion
// ----------------------
module "bastion_east" {
  source              = "../modules/bastion/"
  name                = "bastion"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.bastion.id
}
// ----------------------
// Load Balancer
// ----------------------
resource "azurerm_lb" "example" {
  name                = "lb-example"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "privateIPAddress"
    zones                         = ["1", "2", "3"]
    subnet_id                     = azurerm_subnet.default.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_lb_backend_address_pool" "example" {
  loadbalancer_id = azurerm_lb.example.id
  name            = "BackEndAddressPool"
}

resource "azurerm_network_interface_backend_address_pool_association" "linuxvm1" {
  count = length(module.linuxvm)

  network_interface_id    = module.linuxvm[count.index].network_interface_id
  ip_configuration_name   = module.linuxvm[count.index].ip_configuration_name
  backend_address_pool_id = azurerm_lb_backend_address_pool.example.id
}

resource "azurerm_lb_probe" "example" {
  loadbalancer_id = azurerm_lb.example.id
  name            = "http-running-probe"
  port            = 80
  protocol        = "Http"
  request_path    = "/"
}
resource "azurerm_lb_rule" "example" {
  loadbalancer_id                = azurerm_lb.example.id
  probe_id                       = azurerm_lb_probe.example.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.example.id]
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.example.frontend_ip_configuration[0].name
}

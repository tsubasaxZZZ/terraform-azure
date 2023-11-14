terraform {
  required_version = "~> 1.6"
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

resource "azurerm_resource_group" "example" {
  name     = var.rg.name
  location = var.rg.location
}

resource "random_string" "uniqstr" {
  length  = 8
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
// ----------------------------------------
// Network
// ----------------------------------------
module "vnet_addr_aro" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.aro_base_cidr_block
  networks = [
    {
      name     = "master",
      new_bits = 1
    },
    {
      name     = "worker",
      new_bits = 1
    },

  ]
}

module "vnet_addr" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.base_cidr_block
  networks = [
    {
      name     = "default",
      new_bits = 8
    },
    {
      name     = "bastion",
      new_bits = 8
    },
    {
      name     = "firewall",
      new_bits = 8
    }
  ]
}

resource "azurerm_virtual_network" "example" {
  name                = "vnet-aro-private"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = [module.vnet_addr_aro.base_cidr_block, module.vnet_addr.base_cidr_block]
}

resource "azurerm_subnet" "master" {
  name                 = "snet-master"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = [module.vnet_addr_aro.network_cidr_blocks["master"]]
}
resource "azurerm_subnet" "worker" {
  depends_on = [
    azurerm_subnet.master,
  ]
  name                 = "snet-worker"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = [module.vnet_addr_aro.network_cidr_blocks["worker"]]
}
resource "azurerm_subnet" "default" {
  depends_on = [
    azurerm_subnet.worker,
  ]
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = [module.vnet_addr.network_cidr_blocks["default"]]
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
  address_prefixes     = [module.vnet_addr.network_cidr_blocks["bastion"]]
}
resource "azurerm_subnet" "azfw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.bastion,
  ]
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = [module.vnet_addr.network_cidr_blocks["firewall"]]
}

module "linuxvm" {
  source = "../modules/vm-linux"

  count = var.linux.numberOfVMs

  admin_username = "azureuser"
  // Get ssh password if it's not provided from ssh key from file
  public_key          = var.linux.ssh_public_key
  admin_password      = var.linux.admin_password
  name                = "vmlinux-${count.index + 1}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.default.id
  custom_data         = <<EOF
${var.linux.custom_data}
EOF
}

module "windowsvm" {
  source = "../modules/vm-windows-2019"

  count = var.windows.numberOfVMs

  admin_username      = var.windows.admin_username
  admin_password      = var.windows.admin_password
  name                = "vmwindows-${count.index + 1}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.default.id
}

// --- Azure Bastion ---
module "bastion" {
  depends_on = [
    module.linuxvm,
    module.windowsvm,
  ]
  source              = "../modules/bastion/"
  name                = "bastion"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.bastion.id
}

resource "azurerm_role_assignment" "rp_aad_sp_object_id_to_rt_aro" {
  scope                = azurerm_route_table.aro.id
  role_definition_name = "Network Contributor"
  principal_id         = var.aro_cluster.rp_aad_sp_object_id
}

module "aro" {
  depends_on = [
    module.azfw,
    azurerm_subnet_route_table_association.master,
    azurerm_subnet_route_table_association.worker,
  ]
  source              = "../modules/aro"
  cluster_name        = "aro-${var.aro_cluster.domain}"
  domain              = var.aro_cluster.domain
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  virtual_network_id  = azurerm_virtual_network.example.id
  master_subnet_name  = azurerm_subnet.master.name
  worker_subnet_name  = azurerm_subnet.worker.name

  worker_node_count                = var.aro_cluster.worker_node_count
  aro_cluster_aad_sp_client_id     = var.aro_cluster.aad_sp_client_id
  aro_cluster_aad_sp_object_id     = var.aro_cluster.aad_sp_object_id
  aro_cluster_aad_sp_client_secret = var.aro_aad_sp_client_secret
  aro_rp_aad_sp_object_id          = var.aro_cluster.rp_aad_sp_object_id
  api_server_visibility            = var.aro_cluster.api_server_visibility
  ingress_visibility               = var.aro_cluster.ingress_visibility
  outbound_type                    = var.aro_cluster.outbound_type
}

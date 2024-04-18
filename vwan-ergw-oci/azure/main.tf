
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
  source              = "../../modules/log_analytics"
  name                = "la-${random_string.uniqstr.result}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
}

// ----------------------------------------
// Network
// ----------------------------------------
module "vnet_addr" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.base_cidr_block
  networks = [
    {
      name     = "default"
      new_bits = 8
    },
    {
      name     = "bastion",
      new_bits = 8
    },
    {
      name     = "gateway",
      new_bits = 8
    }
  ]
}

resource "azurerm_virtual_network" "example" {
  name                = "vnet-example"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = [module.vnet_addr.base_cidr_block]
}
resource "azurerm_subnet" "default" {
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

resource "azurerm_subnet" "gateway" {
  depends_on = [
    azurerm_subnet.bastion
  ]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = [module.vnet_addr.network_cidr_blocks["gateway"]]
}

module "linuxvm" {
  source = "../../modules/vm-linux"

  count = 1

  admin_username      = "azureuser"
  name                = "vmlinux-${count.index + 1}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.default.id
}

module "windowsvm" {
  source = "../../modules/vm-windows-2019"

  count = 1

  admin_username      = "azureuser"
  admin_password      = "Passw@rd1!"
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
    module.ergw
  ]
  source              = "../../modules/bastion/"
  name                = "bastion"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.bastion.id
}

module "ergw" {
  source                      = "../../modules/ergateway"
  name                        = "gw-${random_string.uniqstr.result}"
  resource_group_name         = azurerm_resource_group.example.name
  resource_group_location     = azurerm_resource_group.example.location
  subnet_id                   = azurerm_subnet.gateway.id
  remote_vnet_traffic_enabled = true
  virtual_wan_traffic_enabled = true
  depends_on                  = [azurerm_resource_group.example]
}


resource "azurerm_express_route_circuit" "example" {
  name                  = "er-to-oci"
  resource_group_name   = azurerm_resource_group.example.name
  location              = azurerm_resource_group.example.location
  service_provider_name = "Oracle Cloud FastConnect"
  peering_location      = "Tokyo"
  bandwidth_in_mbps     = 50

  sku {
    tier   = "Standard"
    family = "MeteredData"
  }

}

resource "azurerm_virtual_network" "onprem" {
  name                = "vnet-onprem"
  resource_group_name = var.rg.name
  location            = var.rg.location
  address_space       = [module.onprem_vnet_subnet_addrs.base_cidr_block]
}

module "onprem_vnet_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.onprem_vnet.base_cidr_block
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
  ]
}

resource "azurerm_subnet" "onprem_default" {
  name                 = "snet-default"
  resource_group_name  = var.rg.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = [module.onprem_vnet_subnet_addrs.network_cidr_blocks["default"]]
}
resource "azurerm_subnet" "onprem_bastion" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.onprem_default,
  ]
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.rg.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = [module.onprem_vnet_subnet_addrs.network_cidr_blocks["bastion"]]
}

resource "azurerm_subnet" "onprem_vpngw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.onprem_bastion,
  ]
  name                 = "GatewaySubnet"
  resource_group_name  = var.rg.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = [module.onprem_vnet_subnet_addrs.network_cidr_blocks["vpngw"]]
}

module "bastion_onprem" {
  depends_on = [
    module.vpngw_onprem
  ]
  source              = "../../modules/bastion"
  name                = "bastion-onprem"
  resource_group_name = var.rg.name
  location            = var.rg.location
  subnet_id           = azurerm_subnet.onprem_bastion.id
}

module "vm-onprem1" {
  source              = "../../modules/vm-linux"
  resource_group_name = var.rg.name
  location            = var.rg.location
  name                = "vm-${var.environment_name}-onprem1"
  zone                = "1"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  subnet_id           = azurerm_subnet.onprem_default.id
}

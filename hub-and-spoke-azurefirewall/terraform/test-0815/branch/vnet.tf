resource "azurerm_virtual_network" "branch" {
  name                = "vnet-branch"
  resource_group_name = var.rg.name
  location            = var.rg.location
  address_space       = [module.branch_vnet_subnet_addrs.base_cidr_block]
}

module "branch_vnet_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.branch_vnet.base_cidr_block
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

resource "azurerm_subnet" "branch_default" {
  name                 = "snet-default"
  resource_group_name  = var.rg.name
  virtual_network_name = azurerm_virtual_network.branch.name
  address_prefixes     = [module.branch_vnet_subnet_addrs.network_cidr_blocks["default"]]
}
resource "azurerm_subnet" "branch_bastion" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.branch_default,
  ]
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.rg.name
  virtual_network_name = azurerm_virtual_network.branch.name
  address_prefixes     = [module.branch_vnet_subnet_addrs.network_cidr_blocks["bastion"]]
}

resource "azurerm_subnet" "branch_vpngw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.branch_bastion,
  ]
  name                 = "GatewaySubnet"
  resource_group_name  = var.rg.name
  virtual_network_name = azurerm_virtual_network.branch.name
  address_prefixes     = [module.branch_vnet_subnet_addrs.network_cidr_blocks["vpngw"]]
}

module "bastion_branch" {
  depends_on = [
    module.vpngw_branch
  ]
  source              = "../../modules/bastion"
  name                = "bastion-branch"
  resource_group_name = var.rg.name
  location            = var.rg.location
  subnet_id           = azurerm_subnet.branch_bastion.id
}

module "vm-branch1" {
  source              = "../../modules/vm-linux"
  resource_group_name = var.rg.name
  location            = var.rg.location
  name                = "vm-${var.environment_name}-branch1"
  zone                = "1"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  subnet_id           = azurerm_subnet.branch_default.id
}

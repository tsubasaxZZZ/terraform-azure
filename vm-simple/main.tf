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

module "linuxvm" {
  source = "../modules/vm-linux"

  count = var.linux.numberOfVMs

  admin_username      = "azureuser"
  public_key          = var.linux.ssh_public_key
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

  admin_username      = "azureuser"
  admin_password      = "Password1!"
  name                = "vmwindows-${count.index + 1}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.default.id
}

// --- Azure Bastion ---
module "bastion_east" {
  source              = "../modules/bastion/"
  name                = "bastion"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.bastion.id
}

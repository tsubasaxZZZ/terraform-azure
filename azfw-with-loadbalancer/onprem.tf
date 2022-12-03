module "onprem_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.base_cidr_block_onprem
  networks = [
    {
      name     = "default"
      new_bits = 8
    }
  ]
}

resource "azurerm_virtual_network" "onprem" {
  name                = "vnet-onprem"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = [var.base_cidr_block_onprem]
}
resource "azurerm_subnet" "default_onprem" {
  name                = "snet-default"
  resource_group_name = azurerm_resource_group.example.name
  virtual_network_name      = azurerm_virtual_network.onprem.name
  address_prefixes    = [module.onprem_subnet_addrs.network_cidr_blocks["default"]]
}
// ------------------------------------------
// Peering
// ------------------------------------------
resource "azurerm_virtual_network_peering" "onpremToExample" {
  name                      = "onpremToExample"
  resource_group_name = azurerm_resource_group.example.name
  virtual_network_name      = azurerm_virtual_network.onprem.name
  remote_virtual_network_id = azurerm_virtual_network.example.id
}
resource "azurerm_virtual_network_peering" "exampleToOnprem" {
  name                      = "exampleToOnprem"
  resource_group_name = azurerm_resource_group.example.name
  virtual_network_name      = azurerm_virtual_network.example.name
  remote_virtual_network_id = azurerm_virtual_network.onprem.id
}
module "linuxvm_onprem" {
  source = "../modules/vm-linux"

  admin_username      = "azureuser"
  public_key          = var.ssh_public_key
  name                = "vmlinux-onprem"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.default_onprem.id
}

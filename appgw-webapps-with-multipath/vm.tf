module "jumpbox" {
  source              = "../modules/vm-windows-2019/"
  admin_username      = "adminuser"
  admin_password      = "Password1!"
  name                = "vmjumpbox"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.backend.id
}
module "jumpbox-linux" {
  source              = "../modules/vm-linux/"
  admin_username      = "adminuser"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "vmjumpboxlinux"
  subnet_id           = azurerm_subnet.backend.id
  public_key          = file("~/.ssh/id_rsa.pub")
  custom_data         = "test"
}

module "webserver" {
  source              = "../modules/vm-linux/"
  admin_username      = "adminuser"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "vmwebserver"
  subnet_id           = azurerm_subnet.backend.id
  public_key          = file("~/.ssh/id_rsa.pub")
  custom_data         = "sudo apt update && sudo apt install -y nginx"
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
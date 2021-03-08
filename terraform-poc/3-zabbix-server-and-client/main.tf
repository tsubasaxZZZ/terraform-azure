terraform {
  required_version = "~> 0.14.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.50.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "resource_group_name" {
  default = "rg-poc-zabbix"
}
variable "location" {
}
variable "ssh_key_path" {

}
variable "custom_image_resource_group_name" {

}
variable "zabbix_server_custom_image_name" {

}
variable "zabbix_client_custom_image_name" {

}

resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-zabbix"
  address_space       = ["10.0.0.0/8"]
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
}

resource "azurerm_subnet" "subnet_default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}
resource "azurerm_network_security_group" "example" {
  name                = "nsg-zabbix"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
}
resource "azurerm_network_security_rule" "nsg-rule" {
  name                        = "remote_access"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["22", "80"]
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.example.name
  network_security_group_name = azurerm_network_security_group.example.name
}
resource "azurerm_subnet_network_security_group_association" "nsg-assosiation" {
  subnet_id                 = azurerm_subnet.subnet_default.id
  network_security_group_id = azurerm_network_security_group.example.id
}

/******************\
        VM
\******************/
data "azurerm_image" "zabbix_server" {
  name                = var.zabbix_server_custom_image_name
  resource_group_name = var.custom_image_resource_group_name
}
data "azurerm_image" "zabbix_client" {
  name                = var.zabbix_client_custom_image_name
  resource_group_name = var.custom_image_resource_group_name
}

module "zabbix_server" {
  source              = "./modules/linux_from_customimage"
  admin_username      = "tsunomur"
  public_key          = file(var.ssh_key_path)
  name                = "vmzabbixserver"
  vm_size             = "Standard_B2ms"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.subnet_default.id
  zone                = 1
  source_image_id     = data.azurerm_image.zabbix_server.id
}

module "zabbix_client" {
  count               = 3
  source              = "./modules/linux_from_customimage"
  admin_username      = "tsunomur"
  public_key          = file(var.ssh_key_path)
  name                = "vmzabbixclient${count.index + 1}"
  vm_size             = "Standard_B2ms"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.subnet_default.id
  zone                = (count.index % 3) + 1
  source_image_id     = data.azurerm_image.zabbix_client.id
  custom_data         = <<EOF
#!/bin/bash
sudo sed -i.org s/REPLACE_ZABBIX_SERVER_IP/${module.zabbix_server.private_ip_address}/g /etc/zabbix/zabbix_agentd.conf
sudo sed -i.org2 s/REPLACE_ZABBIX_CLIENT_HOSTNAME/$(uname -n)/g /etc/zabbix/zabbix_agentd.conf
sudo systemctl restart zabbix-agent
EOF
}

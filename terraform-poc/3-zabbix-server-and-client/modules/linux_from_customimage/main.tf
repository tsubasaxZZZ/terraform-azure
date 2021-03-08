variable "resource_group_name" {
  
}
variable "location" {
  
}
variable "vm_size" {
  
}
variable "zone" {
  
}
variable "admin_username" {
  
}
variable "name" {
  
}
variable "subnet_id" {
  
}
variable "source_image_id" {
  
}
variable "custom_data" {
  default =<<EOF
#!/bin/bash
EOF
}
variable "public_key" {
  
}

resource "azurerm_public_ip" "pip" {
  name                = "pip-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_linux_virtual_machine" "linux" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  zone                = var.zone
  admin_username      = var.admin_username
  
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.example.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_id = var.source_image_id

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.public_key
  }
  custom_data = base64encode(var.custom_data)
}

resource "azurerm_network_interface" "example" {
  name                = "nic-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "configuration"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}


output "nic_id" {
  value = azurerm_network_interface.example.id
}
output "ip_configuration_name" {
  value = azurerm_network_interface.example.ip_configuration[0].name
}
output "private_ip_address" {
  value = azurerm_network_interface.example.private_ip_address
}

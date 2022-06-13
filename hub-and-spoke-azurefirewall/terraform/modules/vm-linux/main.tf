resource "azurerm_linux_virtual_machine" "linux" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  zone                = var.zone
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  availability_set_id = var.availability_set_id

  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = var.source_image_reference.publisher
    offer     = var.source_image_reference.offer
    sku       = var.source_image_reference.sku
    version   = var.source_image_reference.version
  }

  custom_data = var.custom_data == null ? null : base64encode(var.custom_data)
}

resource "azurerm_network_interface" "nic" {
  name                          = "nic-${var.name}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  enable_accelerated_networking = var.enable_accelerated_networking

  ip_configuration {
    name                          = "configuration"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.private_ip_address_allocation
    private_ip_address            = var.private_ip_address_allocation == "Dynamic" ? null : var.private_ip_address
  }
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "autoshutdown" {
  virtual_machine_id = azurerm_linux_virtual_machine.linux.id
  location           = azurerm_linux_virtual_machine.linux.location
  enabled            = true

  daily_recurrence_time = "0200"
  timezone              = "Tokyo Standard Time"

  notification_settings {
    enabled = false
  }
}

output "private_ip_address" {
    value = azurerm_network_interface.nic.private_ip_address
}
output "id" {
    value = azurerm_windows_virtual_machine.windows.id
}
variable "admin_username" {}
variable "public_key" {}
variable "resource_group_name" {}
variable "location" {}
variable "name" {}
variable "zone" {
  default = 1
}
variable "vm_size" {
  default = "Standard_B2ms"
}
variable "subnet_id" {}
variable "custom_data" {}
variable "source_address_prefix" {
  default = "*"
}
variable "private_ip_address_allocation" {
  default = "Dynamic"
}
variable "private_ip_address" {
  default = null
}

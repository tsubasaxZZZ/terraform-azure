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

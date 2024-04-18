variable "name" {
  type    = string
}

variable "resource_group_name" {
  type = string
}

variable "resource_group_location" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "sku" {
  type    = string
  default = "Standard"
}

variable "remote_vnet_traffic_enabled" {
  type   = bool
  default = false
}

variable "virtual_wan_traffic_enabled" {
  type   = bool
  default = false
}

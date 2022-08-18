variable "rg" {
  type = object({
    name     = string
    location = string
  })
}

variable "environment_name" {
  type = string
}

variable "admin_username" {
  type      = string
  default   = "adminuser"
  sensitive = true
}

variable "admin_password" {
  type      = string
  default   = "Password1!"
  sensitive = true
}

variable "onprem_vnet" {
  type = object({
    base_cidr_block = string
  })
}

variable "azfw_private_ip_address" {
  type = string
}

variable "hub_vnet_gw_subnet_id" {
  type = string
}

variable "hub_vnet" {
  type = object({
    base_cidr_block = string
  })
}

variable "spoke_vnet1" {
  type = object({
    base_cidr_block = string
  })
}

variable "spoke_vnet2" {
  type = object({
    base_cidr_block = string
  })
}

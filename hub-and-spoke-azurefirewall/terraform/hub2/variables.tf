variable "rg" {
  type = object({
    name     = string
    location = string
  })
  default = {
    name     = "rg-hubspoke-hub2"
    location = "japaneast"
  }
}

variable "environment_name" {
  type    = string
  default = "hub2"
}

variable "hub1" {
  type = object({
    vnet_name             = string
    azfw_name             = string
    resource_group_name   = string
    spoke1_vnet_name      = string
    spoke2_vnet_name      = string
    azfw_route_table_name = string
  })
  default = {
    resource_group_name   = "rg-hubspoke-hub1"
    vnet_name             = "vnet-hub1"
    azfw_name             = "afw-hub1"
    spoke1_vnet_name      = "vnet-hub1-spoke1"
    spoke2_vnet_name      = "vnet-hub1-spoke2"
    azfw_route_table_name = "rt-hub-azfw"
  }
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

variable "hub_vnet" {
  type = object({
    base_cidr_block = string
  })
  default = {
    base_cidr_block = "10.1.0.0/16"
  }
}

variable "spoke_vnet1" {
  type = object({
    base_cidr_block = string
  })
  default = {
    base_cidr_block = "10.101.0.0/16"
  }
}

variable "spoke_vnet2" {
  type = object({
    base_cidr_block = string
  })
  default = {
    base_cidr_block = "10.201.0.0/16"
  }
}

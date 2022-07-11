variable "rg" {
  type = object({
    name     = string
    location = string
  })
  default = {
    name     = "rg-hubspoke-hub1"
    location = "japaneast"
  }
}

variable "deploy_onprem_environment" {
  type = bool
  default = false
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
  default = {
    base_cidr_block = "192.168.0.0/16"
  }
}

variable "hub_vnet" {
  type = object({
    base_cidr_block = string
  })
  default = {
    base_cidr_block = "10.0.0.0/16"
  }
}

variable "spoke_vnet1" {
  type = object({
    base_cidr_block = string
  })
  default = {
    base_cidr_block = "10.100.0.0/16"
  }
}

variable "spoke_vnet2" {
  type = object({
    base_cidr_block = string
  })
  default = {
    base_cidr_block = "10.200.0.0/16"
  }
}

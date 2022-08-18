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

variable "branch_vnet" {
  type = object({
    base_cidr_block = string
  })
}

variable "spoke2_vnet_gw_subnet_id" {
  type = string
}

variable "spoke_vnet2" {
  type = object({
    base_cidr_block = string
  })
}

variable "rg" {
  type = object({
    name     = string
    location = string
  })
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

variable "ssh_public_key" {
  type = string
}

variable "enable_secure_vwan" {
  type    = bool
  default = false
}

variable "azure_east" {
  type = object({
    spoke_base_cidr_block = string
    location              = string
    vwan_address_prefix   = string
  })
  default = {
    spoke_base_cidr_block = "10.2.0.0/16"
    location              = "japaneast"
    vwan_address_prefix   = "10.1.0.0/16"
  }
}

variable "azure_west" {
  type = object({
    spoke_base_cidr_block = string
    location              = string
    vwan_address_prefix   = string
  })
  default = {
    spoke_base_cidr_block = "10.20.0.0/16"
    location              = "japanwest"
    vwan_address_prefix   = "10.10.0.0/16"
  }
}

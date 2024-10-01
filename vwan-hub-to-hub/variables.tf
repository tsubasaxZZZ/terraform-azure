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
    spoke_base_cidr_block = optional(string, "172.17.0.0/16")
    location              = optional(string, "japaneast")
    vwan_address_prefix   = optional(string, "172.16.0.0/16")
    deploy_er_gateway     = optional(bool, false)
  })
  default = {

  }
}


variable "azure_east_spokes" {
  type = list(object({
    name                  = string
    spoke_base_cidr_block = string
  }))
  default = [
    {
      name                  = "spoke1"
      spoke_base_cidr_block = "172.18.0.0/16"
    },
    {
      name                  = "spoke2"
      spoke_base_cidr_block = "172.19.0.0/16"
    }
  ]
}

variable "azure_east_shared" {
  type = object({
    spoke_base_cidr_block = string
    location              = string
  })
  default = {
    spoke_base_cidr_block = "172.20.0.0/16"
    location              = "japaneast"
  }
}

variable "azure_west" {
  type = object({
    spoke_base_cidr_block = optional(string, "172.21.0.0/16")
    location              = optional(string, "japanwest")
    vwan_address_prefix   = optional(string, "172.22.0.0/16")
    deploy_vpn_gateway    = optional(bool, false)
  })
  default = {}
}

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

variable "onprem_west" {
  type = object({
    base_cidr_block = string
  })
  default = {
    base_cidr_block = "192.168.0.0/16"
  }
}

variable "onprem_east" {
  type = object({
    base_cidr_block = string
  })
  default = {
    base_cidr_block = "192.168.1.0/16"
  }
}

variable "azure_west" {
  type = object({
    base_cidr_block = string
    location        = string
  })
  default = {
    base_cidr_block = "10.2.0.0/16"
    location        = "japanwest"
  }
}

variable "azure_east" {
  type = object({
    base_cidr_block = string
    location        = string
  })
  default = {
    base_cidr_block = "10.1.0.0/16"
    location        = "japaneast"
  }
}

variable "msee_east" {
  type = list(object({
    auth_key    = string
    peering_url = string
  }))
}

variable "msee_west" {
  type = list(object({
    auth_key    = string
    peering_url = string
  }))
}

variable "dmsee_east" {
  type = list(object({
    auth_key    = string
    peering_url = string
  }))
}

variable "dmsee_west" {
  type = list(object({
    auth_key    = string
    peering_url = string
  }))
}

variable "east_frrconf_url" {
  type = string
}
variable "west_frrconf_url" {
  type = string
}
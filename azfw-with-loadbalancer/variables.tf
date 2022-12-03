variable "rg" {
  type = object({
    name     = string
    location = string
  })
}

variable "admin_username" {
  type      = string
  default   = "adminuser"
}

variable "admin_password" {
  type      = string
  default   = "Password1!"
  sensitive = true
}

variable "ssh_public_key" {
  type = string
}
variable "base_cidr_block" {
  type = string
  default = "10.123.0.0/16"
}

variable "base_cidr_block_onprem" {
  type = string
  default = "10.124.0.0/16"
}

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
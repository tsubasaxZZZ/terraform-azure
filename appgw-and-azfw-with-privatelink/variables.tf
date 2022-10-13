variable "rg" {
  type = object({
    name     = string
    location = string
  })
}

variable "id" {
  type = string
}

variable "source_ip_range" {
  type = string
}

variable "sku" {
  type    = string
  default = "Standard"
}

variable "ssh_public_key" {
  type = string
}
variable "admin_username" {
  type    = string
  default = "azureuser"
}

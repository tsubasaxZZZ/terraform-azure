variable "rg" {
  type = object({
    name     = string
    location = string
  })
}

variable "base_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "windows" {
  type = object({
    numberOfVMs    = number
    admin_username = optional(string, "azureuser")
    admin_password = optional(string, "Password1!")
  })
  default = {
    numberOfVMs    = 0
  }
}

variable "linux" {
  type = object({
    numberOfVMs    = number
    ssh_public_key = optional(string)
    custom_data    = optional(string, "")
  })
  default = {
    numberOfVMs = 0
  }
}

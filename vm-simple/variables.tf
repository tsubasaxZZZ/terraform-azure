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

variable "custom_data" {
  type    = string
  default = ""
}

variable "windows" {
  type = object({
    numberOfVMs = number
  })
  default = {
    numberOfVMs = 1
  }
}

variable "linux" {
  type = object({
    numberOfVMs    = number
    ssh_public_key = string
    custom_data    = string
  })
  default = {
    numberOfVMs    = 1
    ssh_public_key = ""
    custom_data    = ""
  }
}

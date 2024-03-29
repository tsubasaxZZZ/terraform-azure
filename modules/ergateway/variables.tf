variable "name" {
  type    = string
}

variable "rg" {
  type = object({
    name     = string
    location = string
  })
}

variable "subnet_id" {
  type = string
}

variable "sku" {
  type    = string
  default = "Standard"
}

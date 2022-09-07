variable "rg" {
  type = object({
    name     = string
    location = string
  })
}

variable "id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "source_ip_range" {
  type = string
}

variable "sku" {
  type    = string
  default = "Standard"
}

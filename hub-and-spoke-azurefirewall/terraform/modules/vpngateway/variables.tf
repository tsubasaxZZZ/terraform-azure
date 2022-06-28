variable "name" {
  type    = string
}

variable "rg" {
  type = object({
    name     = string
    location = string
  })
}

variable "bgp" {
  type = object({
    asn = number
  })
  default = {
    asn = 65515
  }
}

variable "subnet_id" {
  type = string
}

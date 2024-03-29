variable "rg" {
  type = object({
    name     = string
    location = string
  })
}

variable "er_circuit_location" {
  type = string
}
variable "base_cidr_block" {
  type    = string
  default = "10.1.0.0/16"
}

variable deploy_vwan {
  type    = bool
  default = false
}
variable "vwan_address_prefix" {
  type    = string
  default = "10.3.0.0/16"
}

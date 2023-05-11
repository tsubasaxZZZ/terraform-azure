variable "rg" {
  type = object({
    name     = string
    location = string
  })
}
variable "ssh_public_key" {
  type = string
}

variable "base_cidr_block" {
  type    = string
  default = "172.16.0.0/16"
}

variable "numberOfVMs" {
  type    = number
  default = 2
}


variable "rg" {
  type = object({
    name     = string
    location = string
  })
}

variable "ssh_public_key" {
  type = string
}

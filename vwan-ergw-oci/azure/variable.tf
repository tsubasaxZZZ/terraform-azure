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

variable "deploy_vwan" {
  type    = bool
  default = false
}
variable "vwan_address_prefix" {
  type    = string
  default = "10.3.0.0/16"
}

// If you want to connect to a remote ER circuit, provide the ER circuit ID and key
variable "vwan_remote_er_id_and_key" {
  type = object({
    er_circuit_id        = optional(string)
    er_authorization_key = optional(string)
  })
  default = null
}

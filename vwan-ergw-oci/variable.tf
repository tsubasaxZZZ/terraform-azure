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

variable "oci_configuration" {
  type = object({
    tenancy_ocid     = string
    user_ocid        = string
    private_key_path = string
    fingerprint      = string
    region           = string
    compartment_id   = string
  })
}

variable "oci_base_cidr_block" {
  type    = string
  default = "10.2.0.0/16"
}

variable "ssh_authorized_keys" {
  type = string
}

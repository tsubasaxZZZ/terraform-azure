variable "azure_base_cidr_block" {
  type    = string
  default = "10.1.0.0/16"
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

// Specify the SSH Public Key file path
variable "ssh_authorized_keys" {
  type = string
}

variable "rg" {
  type = object({
    name     = string
    location = string
  })
}

variable "aro_base_cidr_block" {
  type    = string
  default = "10.0.0.0/22"
}

variable "base_cidr_block" {
  type    = string
  default = "192.168.0.0/16"
}

variable "windows" {
  type = object({
    numberOfVMs    = number
    admin_username = optional(string, "azureuser")
    admin_password = optional(string, "Password1!")
  })
  default = {
    numberOfVMs = 0
  }
}

variable "linux" {
  type = object({
    numberOfVMs    = number
    ssh_public_key = optional(string)
    admin_password = optional(string)
    custom_data    = optional(string, "")
  })
  default = {
    numberOfVMs = 0
  }
}

variable "aro_cluster" {
  type = object({
    aad_sp_client_id = string
    aad_sp_object_id = string
    // az ad sp list --display-name "Azure Red Hat OpenShift RP" --query [0].id -o tsv
    rp_aad_sp_object_id   = string
    api_server_visibility = optional(string, "Private")
    ingress_visibility    = optional(string, "Private")

    worker_node_count = optional(number, 3)

    outbound_type = optional(string, "UserDefinedRouting")

    domain = string

    service_cidr = optional(string, "172.30.0.0/16")
    pod_cidr     = optional(string, "10.128.0.0/14")

    version = optional(string)
  })
  // check api_server_visibility and ignore ingress_visibility ether Public or Private
  validation {
    condition     = contains(["Public", "Private"], var.aro_cluster.api_server_visibility)
    error_message = "api_server_visibility must be either Public or Private"
  }
  validation {
    condition     = contains(["Public", "Private"], var.aro_cluster.ingress_visibility)
    error_message = "ingress_visibility must be either Public or Private"
  }
}
variable "aro_aad_sp_client_secret" {
  type      = string
  sensitive = true
}

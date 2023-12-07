variable "cluster_name" {
  type        = string
  description = "The name of the cluster."
}
variable "resource_group_name" {
  type        = string
  description = "The name of the resource group."
}
variable "location" {
  type        = string
  description = "The location of the resource."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "The tags to assign to the resource."
}

variable "domain" {
  type        = string
  description = "The domain of the cluster."
}

variable "fips_validated_modules" {
  type        = string
  default     = "Disabled"
  description = "Whether FIPS validated modules are used."
}

variable "pull_secret" {
  type        = string
  default     = null
  description = "The pull secret for the cluster."
}

variable "pod_cidr" {
  type        = string
  default     = "10.128.0.0/14"
  description = "The CIDR for the pods."
}

variable "service_cidr" {
  type        = string
  default     = "172.30.0.0/16"
  description = "The CIDR for the services."
}

variable "outbound_type" {
  type = string
  validation {
    // Loadbalancer or UserDefinedRouting
    condition     = var.outbound_type == "Loadbalancer" || var.outbound_type == "UserDefinedRouting"
    error_message = "The outbound type must be either Loadbalancer or UserDefinedRouting."
  }
  default     = "Loadbalancer"
  description = "The outbound type."
}


variable "master_node_vm_size" {
  type        = string
  default     = "Standard_D8s_v3"
  description = "The VM size of the master node."
}

variable "master_encryption_at_host" {
  type        = string
  default     = "Disabled"
  description = "Whether encryption at host is enabled for the master node."
}

variable "worker_profile_name" {
  type        = string
  default     = "worker"
  description = "The name of the worker profile."
}

variable "worker_node_vm_size" {
  type        = string
  default     = "Standard_D4s_v3"
  description = "The VM size of the worker node."
}

variable "worker_node_vm_disk_size" {
  type        = number
  default     = 128
  description = "The disk size of the worker node in GB."
}

variable "worker_node_count" {
  type        = number
  default     = 3
  description = "The number of worker nodes."
}

variable "worker_encryption_at_host" {
  type        = string
  default     = "Disabled"
  description = "Whether encryption at host is enabled for the worker node."
}

variable "api_server_visibility" {
  type        = string
  default     = "Public"
  description = "The visibility of the API server."
}

variable "ingress_profile_name" {
  type        = string
  default     = "default"
  description = "The name of the ingress profile."
}

variable "ingress_visibility" {
  type        = string
  default     = "Public"
  description = "The visibility of the ingress."
}

variable "aro_rp_aad_sp_object_id" {
  type        = string
  description = "The object ID of the AAD service principal for the ARO resource provider."
}

variable "aro_cluster_aad_sp_client_id" {
  type        = string
  description = "The client ID of the AAD service principal for the ARO cluster."
}

variable "aro_cluster_aad_sp_client_secret" {
  type        = string
  sensitive   = true
  description = "The client secret of the AAD service principal for the ARO cluster."
}
variable "aro_cluster_aad_sp_object_id" {
  type        = string
  description = "The object ID of the AAD service principal for the ARO cluster."
}

variable "aro_version" {
  type        = string
  default     = null
  description = "The version of the ARO cluster."
}

variable "virtual_network_id" {
  type        = string
  description = "The ID of the virtual network."
}

variable "master_subnet_name" {
  type        = string
  description = "The name of the master subnet."
}
variable "worker_subnet_name" {
  type        = string
  description = "The name of the worker subnet."
}

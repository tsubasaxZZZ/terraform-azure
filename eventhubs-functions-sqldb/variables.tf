variable "environment_name" {
  default = "poc"
}
variable "connection_from_ipaddress" {
}
variable "resource_group1_name" {
}
variable "resource_group1_location" {
}
variable "resource_group2_name" {
}
variable "resource_group2_location" {
}

// SQL Database
variable "sqldb_admin" {
  default = "sqldbadmin"
}
variable "sqldb_password" {
  default = "Password1!"
}
variable "sqldb_edition" {
  default = "Hyperscale"
}
variable "sqldb_service" {
  default = "HS_Gen5_8"
}

// Event Hubs
variable "eventhubs_capacity" {
  default = 1
}
variable "eventhubs_sku" {
  default = "Standard"
}
variable "eventhubs_instance_partition_count" {
  default = 1
}
variable "eventhubs_instance_message_retention" {
  default = 1
}
variable "eventhubs_auto_inflate_enabled" {
  default = true
}
variable "eventhubs_maximum_throughput_units" {
  default = 20
}

// VM
variable "ssh_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

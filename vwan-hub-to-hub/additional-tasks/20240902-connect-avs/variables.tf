variable "rg" {
  type = object({
    name     = string
    location = string
  })
}

variable "vwan_id" {
  type = string
}

variable "address_cidrs" {
  type    = list(string)
  default = ["192.168.0.0/16"]
}

variable "remote_ip_address" {
  type    = string
  default = "210.165.210.220"
}

variable "vpn_site" {
  type = object({
    device_vendor = string
    link = object({
      name = string
      bgp = object({
        asn             = number
        peering_address = string
      })
      provider_name = string
      ip_address    = string
    })
  })
}

variable "vpn_gateway_id" {
  type = string
}

variable "express_route_connection" {
  type = object({
    express_route_gateway_id         = string
    express_route_circuit_peering_id = string
    authorization_key                = string
    enable_internet_security         = optional(bool, true)
  })

}


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
  default = "172.26.0.0/16"
}

variable "nva_bgp_asn" {
  type    = number
  default = 65001
}

variable "frr_config_url" {
  type = string
  default = "https://gist.githubusercontent.com/tsubasaxZZZ/8a16096fd90b931ea2a005d38e5d8426/raw/1cd610569c86a9b267aef3c8c36d994ac10d1830/onprem_s2s-internet-via-azfw.conf"
  
}
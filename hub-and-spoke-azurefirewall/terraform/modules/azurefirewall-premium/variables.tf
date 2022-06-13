variable "rg" {
  type = object({
    name     = string
    location = string
  })
}

variable "id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "azurefirewall_network_rule" {
  type = list(object({
    name     = string
    priority = number
    action   = string
    rule = list(object({
      name                  = string
      protocols             = list(string)
      source_addresses      = list(string)
      destination_addresses = list(string)
      destination_ports     = list(string)
    }))
  }))
  default = [
    {
      name     = "AllowNetworkRuleCollection"
      priority = 1000
      action   = "Allow"
      rule = [
        {
          name                  = "All"
          protocols             = ["Any"]
          source_addresses      = ["*"]
          destination_addresses = ["*"]
          destination_ports     = ["*"]
        }
      ]
    }
  ]
}

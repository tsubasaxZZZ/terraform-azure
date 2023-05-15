variable "rg" {
  type = object({
    name     = string
    location = string
  })
}
variable "ssh_public_key" {
  type = string
}

variable "backend_base_cidr_block" {
  type    = string
  default = "172.16.0.0/16"
}

variable "frontend_base_cidr_block" {
  type    = string
  default = "10.254.0.0/16"
}

variable "numberOfVMs" {
  type    = number
  default = 2
}

variable "pattern" {
  type    = string
  validation {
    condition     = can(regex("AppGW-with-PLS|AppGW-with-PLS-and-WAF|AppGW-with-PLS-and-FrontAzFW|AppGW-with-PLS-and-WAF-and-FrontAzFW|AppGW-with-PLS-and-WAF-and-FrontAzFW-and-BackendAzFW", var.pattern))
    error_message = "Pattern must be aligned one of the specified patterns"
  }
  default = "AppGW-with-PLS"
}

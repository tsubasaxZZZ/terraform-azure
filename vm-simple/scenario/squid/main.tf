terraform {
  required_version = "~> 1.3.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}
provider "azurerm" {
  //use_oidc = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

module "squid" {
  source = "../../"
  rg     = var.rg
  linux = {
    numberOfVMs    = 1
    ssh_public_key = var.ssh_public_key
    custom_data    = <<EOF
#cloud-config
packages_update: true
packages_upgrade: true
packages:
  - squid
runcmd:
  - sudo sed -i.org 's/#http_access allow localnet/http_access allow localnet/' /etc/squid/squid.conf
  - sudo sed -i.org.2 -r 's/^#(acl localnet)/\1/g' /etc/squid/squid.conf
  - systemctl restart squid
EOF
  }
}

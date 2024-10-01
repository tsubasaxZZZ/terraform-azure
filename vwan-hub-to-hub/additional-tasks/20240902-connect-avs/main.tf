
provider "azurerm" {
  //use_oidc = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

/////////////////////////////
// VPN for West
/////////////////////////////
resource "azurerm_vpn_site" "example" {
  name                = "site1"
  resource_group_name = var.rg.name
  location            = var.rg.location
  virtual_wan_id      = var.vwan_id
  //address_cidrs       = var.address_cidrs

  #   link {
  #     name       = "link1"
  #     ip_address = var.remote_ip_address
  #   }

  device_vendor = var.vpn_site.device_vendor

  link {
    name = var.vpn_site.link.name
    bgp {
      asn             = var.vpn_site.link.bgp.asn
      peering_address = var.vpn_site.link.bgp.peering_address
    }
    provider_name = var.vpn_site.link.provider_name
    ip_address    = var.vpn_site.link.ip_address
  }
}

resource "azurerm_vpn_gateway_connection" "example" {
  name               = "example"
  vpn_gateway_id     = var.vpn_gateway_id
  remote_vpn_site_id = azurerm_vpn_site.example.id

  vpn_link {
    name             = "link1"
    vpn_site_link_id = azurerm_vpn_site.example.link[0].id
    shared_key       = "share-key"
    bgp_enabled      = true
  }

}

/////////////////////////////
// ExpressRoute for East
/////////////////////////////

resource "azurerm_express_route_connection" "example" {
  name                             = "example-expressrouteconn"
  express_route_gateway_id         = var.express_route_connection.express_route_gateway_id
  express_route_circuit_peering_id = var.express_route_connection.express_route_circuit_peering_id
  authorization_key                = var.express_route_connection.authorization_key
  enable_internet_security         = var.express_route_connection.enable_internet_security
}

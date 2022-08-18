module "vpngw_branch" {
  source = "../../modules/vpngateway"
  name   = "vpng-branch"
  rg = {
    name     = var.rg.name
    location = var.rg.location
  }
  subnet_id = azurerm_subnet.branch_vpngw.id

  bgp = {
    asn = 65516
  }

}

module "vpngw" {
  source = "../../modules/vpngateway"
  name   = "vpng-${var.environment_name}"
  rg = {
    name     = var.rg.name
    location = var.rg.location
  }
  subnet_id = var.spoke2_vnet_gw_subnet_id

  bgp = {
    asn = 65514
  }
}

resource "azurerm_local_network_gateway" "spoke2" {
  name                = var.environment_name
  location            = var.rg.location
  resource_group_name = var.rg.name
  gateway_address     = module.vpngw.public_ip_address
  address_space       = [var.spoke_vnet2.base_cidr_block]

  bgp_settings {
    asn                 = 65514
    bgp_peering_address = module.vpngw.bgp_peering_address
  }
}

resource "azurerm_local_network_gateway" "branch" {
  name                = "branch"
  location            = var.rg.location
  resource_group_name = var.rg.name
  gateway_address     = module.vpngw_branch.public_ip_address
  address_space       = [var.branch_vnet.base_cidr_block]

  bgp_settings {
    asn                 = 65516
    bgp_peering_address = module.vpngw_branch.bgp_peering_address
  }
}

resource "azurerm_virtual_network_gateway_connection" "branch_to_spoke2" {
  name                = "branch-to-${var.environment_name}"
  resource_group_name = var.rg.name
  location            = var.rg.location

  type                       = "IPsec"
  virtual_network_gateway_id = module.vpngw_branch.virtual_network_gateway_id
  local_network_gateway_id   = azurerm_local_network_gateway.spoke2.id

  enable_bgp = true

  shared_key = "4-v3ry-53cr37-1p53c-5h4r3d-k3y"
}

resource "azurerm_virtual_network_gateway_connection" "spoke2_to_branch" {
  name                = "${var.environment_name}-to-branch"
  resource_group_name = var.rg.name
  location            = var.rg.location

  type                       = "IPsec"
  virtual_network_gateway_id = module.vpngw.virtual_network_gateway_id
  local_network_gateway_id   = azurerm_local_network_gateway.branch.id

  enable_bgp = true

  shared_key = "4-v3ry-53cr37-1p53c-5h4r3d-k3y"
}

/*
resource "azurerm_route_table" "spoke2_gw" {
  name                          = "rt-${var.environment_name}-gw"
  resource_group_name           = var.rg.name
  location                      = var.rg.location
  disable_bgp_route_propagation = false

  lifecycle {
    ignore_changes = [
      route
    ]
  }

  route = [
    {
      name                   = "toSpoke1"
      address_prefix         = var.spoke_vnet1.base_cidr_block
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = var.azfw_private_ip_address
    },
    {
      name                   = "toSpoke2"
      address_prefix         = var.spoke_vnet2.base_cidr_block
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = var.azfw_private_ip_address
    },
  ]
}

resource "azurerm_subnet_route_table_association" "spoke2_gw" {
  depends_on = [
    module.vpngw
  ]
  subnet_id      = var.spoke2_vnet_gw_subnet_id
  route_table_id = azurerm_route_table.spoke2_gw.id
}
*/
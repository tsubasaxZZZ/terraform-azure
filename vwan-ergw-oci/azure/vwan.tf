
resource "azurerm_virtual_wan" "example" {
  // If deploy_vwan is set to true, create a Virtual WAN
  count               = var.deploy_vwan ? 1 : 0
  name                = "vwan-avs"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  # Configuration 
  office365_local_breakout_category = "OptimizeAndAllow"

}
resource "azurerm_virtual_hub" "example" {
  count = var.deploy_vwan ? 1 : 0

  name                = "vhub-avs"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  virtual_wan_id      = azurerm_virtual_wan.example.0.id
  address_prefix      = var.vwan_address_prefix
}

resource "azurerm_express_route_gateway" "example" {
  count               = var.deploy_vwan ? 1 : 0

  name                = "expressRoute1"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  virtual_hub_id      = azurerm_virtual_hub.example.0.id
  scale_units         = 1
}


#Firewall Policy
resource "azurerm_firewall_policy" "example" {
  count               = var.deploy_vwan ? 1 : 0

  name                = "pol-example"
  resource_group_name = azurerm_virtual_hub.example.0.resource_group_name
  location            = azurerm_virtual_hub.example.0.location
}
# Firewall Policy Rules
resource "azurerm_firewall_policy_rule_collection_group" "example" {
  count               = var.deploy_vwan ? 1 : 0

  name               = "fw-example-rules"
  firewall_policy_id = azurerm_firewall_policy.example.0.id
  priority           = 2000

  lifecycle {
    ignore_changes = [network_rule_collection, application_rule_collection, nat_rule_collection]
  }

  network_rule_collection {
    name     = "network_rules1"
    priority = 2100
    action   = "Allow"
    rule {
      name                  = "network_rule_collection1_rule1"
      protocols             = ["TCP", "UDP", "ICMP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["*"]
    }
  }
}

resource "azurerm_firewall" "example" {
  count               = var.deploy_vwan ? 1 : 0

  name                = "fw-example"
  resource_group_name = azurerm_virtual_hub.example.0.resource_group_name
  location            = azurerm_virtual_hub.example.0.location
  sku_tier            = "Premium"
  sku_name            = "AZFW_Hub"
  firewall_policy_id  = azurerm_firewall_policy.example.0.id
  virtual_hub {
    virtual_hub_id  = azurerm_virtual_hub.example.0.id
    public_ip_count = 1
  }
}

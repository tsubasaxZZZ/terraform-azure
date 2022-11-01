data "azurerm_monitor_diagnostic_categories" "azfw-diag-categories" {
  resource_id = azurerm_firewall.example.id
}
module "diag_azfw_example" {
  source                     = "../../modules/diagnostic_logs"
  name                       = "diag"
  target_resource_id         = azurerm_firewall.example.id
  log_analytics_workspace_id = var.log_analytics_id
  diagnostic_logs            = data.azurerm_monitor_diagnostic_categories.azfw-diag-categories.logs
  retention                  = 30
}

#Firewall Policy
resource "azurerm_firewall_policy" "example" {
  name                = "pol-${var.id}"
  resource_group_name = var.resource_group_name
  location            = var.location
}
# Firewall Policy Rules
resource "azurerm_firewall_policy_rule_collection_group" "example" {
  name               = "fw-example-rules"
  firewall_policy_id = azurerm_firewall_policy.example.id
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
  name                = "fw-${var.id}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_tier            = "Premium"
  sku_name            = "AZFW_Hub"
  firewall_policy_id  = azurerm_firewall_policy.example.id
  virtual_hub {
    virtual_hub_id  = var.virtual_hub_id
    public_ip_count = 1
  }
}

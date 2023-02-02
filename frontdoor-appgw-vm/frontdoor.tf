
resource "azurerm_cdn_frontdoor_profile" "example" {
  name                = "fd-${random_string.uniqstr.result}"
  resource_group_name = azurerm_resource_group.example.name
  sku_name            = "Premium_AzureFrontDoor"
}

data "azurerm_monitor_diagnostic_categories" "afd_diag_category" {
  resource_id = azurerm_cdn_frontdoor_profile.example.id
}

module "afd_diag" {
  source                     = "../modules/diagnostic_logs"
  name                       = "afd-diag"
  target_resource_id         = azurerm_cdn_frontdoor_profile.example.id
  log_analytics_workspace_id = module.la.id
  diagnostic_logs            = data.azurerm_monitor_diagnostic_categories.afd_diag_category.logs
  retention                  = 30
}

resource "azurerm_cdn_frontdoor_firewall_policy" "example" {
  name                = "fdfp${random_string.uniqstr.result}"
  resource_group_name = azurerm_resource_group.example.name
  sku_name            = azurerm_cdn_frontdoor_profile.example.sku_name
  enabled             = true
  mode                = "Prevention"

  managed_rule {
    type    = "DefaultRuleSet"
    version = "1.0"
    action  = "Log"
  }

  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.0"
    action  = "Log"
  }
}
// endpoint of LB
resource "azurerm_cdn_frontdoor_endpoint" "example" {
  name                     = "endpoint-${random_string.uniqstr.result}-example"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.example.id
}

resource "azurerm_cdn_frontdoor_origin_group" "example" {
  name                     = "example-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.example.id
  session_affinity_enabled = true

  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 10

  health_probe {
    interval_in_seconds = 5
    path                = "/"
    protocol            = "Http"
    request_type        = "HEAD"
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }
}
resource "azurerm_cdn_frontdoor_origin" "example" {
  depends_on = [
    azurerm_private_link_service.example,
    azurerm_lb.example
  ]

  name                          = "example-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.example.id

  health_probes_enabled          = true
  certificate_name_check_enabled = true

  host_name          = local.pls_private_address
  http_port          = 80
  https_port         = 443
  origin_host_header = local.pls_private_address
  priority           = 1
  weight             = 500

  private_link {
    request_message        = "Request access for Private Link Origin CDN Frontdoor"
    location               = azurerm_lb.example.location
    private_link_target_id = azurerm_private_link_service.example.id
  }
}
resource "azurerm_cdn_frontdoor_route" "example" {
  name                          = "example-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.example.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.example.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.example.id]
  cdn_frontdoor_rule_set_ids    = [azurerm_cdn_frontdoor_rule_set.example.id]
  enabled                       = true

  forwarding_protocol    = "MatchRequest"
  https_redirect_enabled = false
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  link_to_default_domain = true

}

// endpoint of AppGW
resource "azurerm_cdn_frontdoor_endpoint" "appgw" {
  name                     = "endpoint-${random_string.uniqstr.result}-appgw"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.example.id
}

resource "azurerm_cdn_frontdoor_origin_group" "appgw" {
  name                     = "appgw-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.example.id
  session_affinity_enabled = true

  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 10

  health_probe {
    interval_in_seconds = 5
    path                = "/"
    protocol            = "Http"
    request_type        = "HEAD"
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }
}
resource "azurerm_cdn_frontdoor_origin" "appgw" {
  name                          = "appgw-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.appgw.id

  health_probes_enabled          = true
  certificate_name_check_enabled = true

  host_name          = azurerm_public_ip.appgw.ip_address
  http_port          = 80
  https_port         = 443
  origin_host_header = azurerm_public_ip.appgw.ip_address
  priority           = 1
  weight             = 500
}
resource "azurerm_cdn_frontdoor_route" "appgw" {
  name                          = "appgw-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.appgw.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.appgw.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.appgw.id]
  cdn_frontdoor_rule_set_ids    = [azurerm_cdn_frontdoor_rule_set.example.id]
  enabled                       = true

  forwarding_protocol    = "MatchRequest"
  https_redirect_enabled = false
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  link_to_default_domain = true

}

// common resources
resource "azurerm_cdn_frontdoor_rule_set" "example" {
  name                     = "ExampleRuleSet"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.example.id
}

resource "azurerm_cdn_frontdoor_security_policy" "example" {
  name                     = "Example-Security-Policy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.example.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.example.id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.example.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}


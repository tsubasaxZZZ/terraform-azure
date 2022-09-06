
resource "azurerm_cdn_frontdoor_profile" "example" {
  name                = "fd-appsvc-${random_string.uniqstr.result}"
  resource_group_name = azurerm_resource_group.example.name
  sku_name            = "Premium_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "example" {
  name                     = "example-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.example.id
}

//------------
// endpoint-1
//------------
resource "azurerm_cdn_frontdoor_origin_group" "example" {
  name                     = "example-originGroup"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.example.id
  session_affinity_enabled = true

  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 10

  health_probe {
    interval_in_seconds = 10
    path                = "/"
    protocol            = "Https"
    request_type        = "GET"
  }

  load_balancing {
    additional_latency_in_milliseconds = 0
    sample_size                        = 16
    successful_samples_required        = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "example" {
  name                          = "example-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.example.id

  health_probes_enabled          = true
  certificate_name_check_enabled = false

  host_name          = azurerm_linux_web_app.app1.default_hostname
  http_port          = 80
  https_port         = 443
  origin_host_header = azurerm_linux_web_app.app1.default_hostname
  priority           = 2
  weight             = 500
}
resource "azurerm_cdn_frontdoor_origin" "example2" {
  name                          = "example-origin2"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.example.id

  health_probes_enabled          = true
  certificate_name_check_enabled = false

  host_name          = azurerm_linux_web_app.app2.default_hostname
  http_port          = 80
  https_port         = 443
  origin_host_header = azurerm_linux_web_app.app2.default_hostname
  priority           = 1
  weight             = 500
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
        patterns_to_match = [
          "/*"
        ]
      }
    }
  }
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

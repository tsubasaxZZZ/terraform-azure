# --------------------------
# VM
# --------------------------
module "vm_appgw" {
  count               = var.numberOfVMs
  source              = "../modules/vm-linux/"
  admin_username      = "adminuser"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "vmappgw${count.index}"
  subnet_id           = azurerm_subnet.default.id
  public_key          = var.ssh_public_key
  custom_data         = <<EOF
#cloud-config
packages_update: true
packages_upgrade: true
packages:
  - nginx
  - nodejs
  - npm
runcmd:
  - echo "<h1>vmappgw${count.index}</h1>" | tee /var/www/html/index.nginx-debian.html
EOF
}

resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

data "azurerm_monitor_diagnostic_categories" "appgw_diag_category" {
  resource_id = azurerm_application_gateway.network.id
}

module "appgw_diag" {
  source                     = "../modules/diagnostic_logs"
  name                       = "diag"
  target_resource_id         = azurerm_application_gateway.network.id
  log_analytics_workspace_id = module.la.id
  diagnostic_logs            = data.azurerm_monitor_diagnostic_categories.appgw_diag_category.logs
  retention                  = 30
}

# since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name_vm           = "${azurerm_virtual_network.example.name}-beap-vm"
  frontend_port_name                     = "${azurerm_virtual_network.example.name}-feport"
  frontend_port_8080_name                = "${azurerm_virtual_network.example.name}-8080-feport"
  frontend_ip_configuration_name         = "${azurerm_virtual_network.example.name}-feip"
  frontend_ip_configuration_private_name = "${azurerm_virtual_network.example.name}-feip-private"
  frontend_ip_private                    = cidrhost(module.azure_subnet_addrs.network_cidr_blocks["appgw"], 4)
  http_setting_name                      = "${azurerm_virtual_network.example.name}-be-htst"
  listener_name                          = "${azurerm_virtual_network.example.name}-httplstn"
  listener_name_private                  = "${azurerm_virtual_network.example.name}-httplstn-private"
  request_routing_rule_name              = "${azurerm_virtual_network.example.name}-rqrt"
  request_routing_rule_private_name      = "${azurerm_virtual_network.example.name}-private-rqrt"
  redirect_configuration_name            = "${azurerm_virtual_network.example.name}-rdrcfg"
  private_link_configuration_name        = "my-private-link-config"

  sku_name = can(regex(".*WAF", var.pattern)) ? "WAF_v2" : "Standard_v2"

}

resource "azurerm_application_gateway" "network" {
  name                = "appgw-example"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  sku {
    name     = local.sku_name
    tier     = local.sku_name
    capacity = 2
  }

  dynamic "waf_configuration" {
    for_each = local.sku_name == "WAF_v2" ? [1] : []
    content {
      enabled          = true
      firewall_mode    = "Detection"
      rule_set_type    = "OWASP"
      rule_set_version = "3.2"

    }
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }
  frontend_port {
    name = local.frontend_port_8080_name
    port = 8080
  }
  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.appgw.id
  }


  frontend_ip_configuration {
    name                            = local.frontend_ip_configuration_private_name
    private_ip_address_allocation   = "Static"
    subnet_id                       = azurerm_subnet.appgw.id
    private_ip_address              = local.frontend_ip_private
    private_link_configuration_name = local.private_link_configuration_name
  }

  // -----------------------
  // BackendPool
  // -----------------------

  // VM
  backend_address_pool {
    name  = local.backend_address_pool_name_vm
    fqdns = [for vm in module.vm_appgw : vm.network_interface_ipconfiguration.0.private_ip_address]
  }

  // -----------------------
  // HTTP Settings
  // -----------------------
  // path: /
  backend_http_settings {
    name                                = local.http_setting_name
    cookie_based_affinity               = "Enabled"
    path                                = ""
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 60
    pick_host_name_from_backend_address = true
  }
  // path: /staging
  backend_http_settings {
    name                                = "${local.http_setting_name}-2"
    cookie_based_affinity               = "Disabled"
    path                                = "/"
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 60
    pick_host_name_from_backend_address = true

  }

  // -----------------------
  // Listener
  // -----------------------
  // from: public
  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  // from: private
  http_listener {
    name                           = local.listener_name_private
    frontend_ip_configuration_name = local.frontend_ip_configuration_private_name
    frontend_port_name             = local.frontend_port_8080_name
    protocol                       = "Http"
  }

  // -----------------------
  // Routing Rule
  // -----------------------
  // for: public
  request_routing_rule {
    name               = local.request_routing_rule_private_name
    rule_type          = "PathBasedRouting"
    http_listener_name = local.listener_name_private
    priority           = "1000"
    url_path_map_name  = "my-url-path-map"
  }
  url_path_map {
    name = "my-url-path-map"
    // path: /
    default_backend_address_pool_name  = local.backend_address_pool_name_vm
    default_backend_http_settings_name = local.http_setting_name
    // path: /staging
    path_rule {
      name                       = "my-path-rule"
      paths                      = ["/staging/*"]
      backend_address_pool_name  = local.backend_address_pool_name_vm
      backend_http_settings_name = "${local.http_setting_name}-2"
    }
  }

  // Private Link Configuration
  private_link_configuration {
    name = local.private_link_configuration_name
    ip_configuration {
      name                          = "my-private-link-config-ip-config"
      private_ip_address_allocation = "Dynamic"
      subnet_id                     = azurerm_subnet.pls.id
      primary                       = true
    }
  }
}

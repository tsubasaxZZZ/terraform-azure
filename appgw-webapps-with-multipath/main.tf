terraform {
  required_version = "~> 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "random_string" "uniqstr" {
  length  = 6
  special = false
  upper   = false
  keepers = {
    resource_group_name = var.rg.name
  }
}

resource "azurerm_resource_group" "example" {
  name     = var.rg.name
  location = var.rg.location
}

# --------------------------
# Web App (Linux)
# --------------------------
resource "azurerm_service_plan" "example" {
  name                = "plan-${random_string.uniqstr.result}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  os_type             = "Linux"
  sku_name            = "S1"
}

resource "azurerm_linux_web_app" "app1" {
  name                = "app-${random_string.uniqstr.result}-1"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_service_plan.example.location
  service_plan_id     = azurerm_service_plan.example.id

  site_config {
    application_stack {
      docker_image     = "tsubasaxzzz/nginx-0829"
      docker_image_tag = "app1"
    }
  }
}

resource "azurerm_linux_web_app" "app2" {
  name                = "app-${random_string.uniqstr.result}-2"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_service_plan.example.location
  service_plan_id     = azurerm_service_plan.example.id

  site_config {
    application_stack {
      docker_image     = "tsubasaxzzz/nginx-0829"
      docker_image_tag = "app2"
    }
  }
}

# --------------------------
# Application Gateway
# --------------------------
resource "azurerm_virtual_network" "example" {
  name                = "vnet-example"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = ["10.254.0.0/16"]
}

resource "azurerm_subnet" "frontend" {
  name                 = "snet-frontend"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.254.0.0/24"]
}

resource "azurerm_subnet" "backend" {
  name                 = "snet-backend"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.254.2.0/24"]
}

resource "azurerm_public_ip" "example" {
  name                = "pip-appgw"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

# since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name_1            = "${azurerm_virtual_network.example.name}-beap-webapps1"
  backend_address_pool_name_2            = "${azurerm_virtual_network.example.name}-beap-webapps2"
  backend_address_pool_name_vm           = "${azurerm_virtual_network.example.name}-beap-vm"
  frontend_port_name                     = "${azurerm_virtual_network.example.name}-feport"
  frontend_port_8080_name                = "${azurerm_virtual_network.example.name}-8080-feport"
  frontend_ip_configuration_name         = "${azurerm_virtual_network.example.name}-feip"
  frontend_ip_configuration_private_name = "${azurerm_virtual_network.example.name}-feip-private"
  frontend_ip_private                    = "10.254.0.4"
  http_setting_name                      = "${azurerm_virtual_network.example.name}-be-htst"
  listener_name                          = "${azurerm_virtual_network.example.name}-httplstn"
  listener_name_private                  = "${azurerm_virtual_network.example.name}-httplstn-private"
  request_routing_rule_name              = "${azurerm_virtual_network.example.name}-rqrt"
  request_routing_rule_private_name      = "${azurerm_virtual_network.example.name}-private-rqrt"
  redirect_configuration_name            = "${azurerm_virtual_network.example.name}-rdrcfg"
}

resource "azurerm_application_gateway" "network" {
  name                = "appgw-example"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.frontend.id
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
    public_ip_address_id = azurerm_public_ip.example.id
  }


  frontend_ip_configuration {
    name                          = local.frontend_ip_configuration_private_name
    private_ip_address_allocation = "Static"
    subnet_id                     = azurerm_subnet.frontend.id
    private_ip_address            = local.frontend_ip_private
  }

  // -----------------------
  // BackendPool
  // -----------------------
  // App Service 1
  backend_address_pool {
    name  = local.backend_address_pool_name_1
    fqdns = [azurerm_linux_web_app.app1.default_hostname]
  }
  // App Service 2
  backend_address_pool {
    name  = local.backend_address_pool_name_2
    fqdns = [azurerm_linux_web_app.app2.default_hostname]
  }
  // VM1
  backend_address_pool {
    name  = local.backend_address_pool_name_vm
    fqdns = [module.webserver.network_interface_ipconfiguration.0.private_ip_address]
  }

  // -----------------------
  // HTTP Settings
  // -----------------------
  // path: /
  backend_http_settings {
    name                                = local.http_setting_name
    cookie_based_affinity               = "Disabled"
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
    name               = local.request_routing_rule_name
    rule_type          = "PathBasedRouting"
    http_listener_name = local.listener_name
    priority           = "1000"
    url_path_map_name  = "my-url-path-map"
  }
  url_path_map {
    name = "my-url-path-map"
    // path: /
    default_backend_address_pool_name  = local.backend_address_pool_name_1
    default_backend_http_settings_name = local.http_setting_name
    // path: /staging
    path_rule {
      name                       = "my-path-rule"
      paths                      = ["/staging/*"]
      backend_address_pool_name  = local.backend_address_pool_name_2
      backend_http_settings_name = "${local.http_setting_name}-2"
    }
  }

  // for: private
  request_routing_rule {
    name               = local.request_routing_rule_private_name
    rule_type          = "PathBasedRouting"
    http_listener_name = local.listener_name_private
    priority           = "2000"
    url_path_map_name  = "my-url-path-map-vm"
  }
  url_path_map {
    name = "my-url-path-map-vm"
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

}

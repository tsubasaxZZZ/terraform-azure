resource "azurerm_resource_group" "frontend" {
  name     = "${var.rg.name}-frontend"
  location = var.rg.location
}

module "fe_azfw" {
  source    = "../modules/azurefirewall-premium"
  rg        = azurerm_resource_group.frontend
  id        = random_string.uniqstr.result
  subnet_id = azurerm_subnet.fe_azfw.id
  sku       = "Premium"

  azurefirewall_application_rule = [{
    name     = "AllowApplicationRuleCollection"
    priority = 2000
    action   = "Allow"
    rule = [
      {
        name                  = "All"
        destination_addresses = []
        destination_fqdn_tags = []
        destination_fqdns     = ["*"]
        destination_urls      = []
        protocols = [
          {
            port = 80
            type = "Http"
          },
          {
            port = 8080
            type = "Http"
          },
          {
            port = 443
            type = "Https"
          }
        ]
        source_addresses = ["*"]
        source_ip_groups = []
        terminate_tls    = false
        web_categories   = []
      }
    ]
  }]

  azurefirewall_network_rule = [{
    action   = "Allow"
    name     = "AllowNetworkRuleCollection"
    priority = 1000
    rule = [
      {
        name                  = "All"
        source_addresses      = ["1.2.3.4"]
        protocols             = ["TCP"]
        destination_ports     = ["*"]
        destination_addresses = ["*"]
        destination_fqdns     = []

      },
    ]
  }]
}

resource "azurerm_route_table" "vm" {
  name                          = "rt-fe-vm"
  resource_group_name           = azurerm_resource_group.frontend.name
  location                      = azurerm_resource_group.frontend.location
  disable_bgp_route_propagation = false

  route = [{
    name                   = "default"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = module.fe_azfw.private_ip_address
    },
    {
      name                   = "backend"
      address_prefix         = module.frontend_azure_subnet_addrs.network_cidr_blocks["pe"]
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = module.fe_azfw.private_ip_address

    }
  ]
}
resource "azurerm_subnet_route_table_association" "fe_vm" {
  count          = can(regex(".*FrontAzFW.*", var.pattern)) ? 1 : 0
  subnet_id      = azurerm_subnet.fe_vm.id
  route_table_id = azurerm_route_table.vm.id
}

module "afw_diag" {
  source                     = "../modules/diagnostic_logs"
  name                       = "diag"
  target_resource_id         = module.fe_azfw.id
  log_analytics_workspace_id = module.la.id
  diagnostic_logs            = data.azurerm_monitor_diagnostic_categories.azfw_diag_category.logs
  retention                  = 30
}

# --------------------------
# VNet
# --------------------------
module "frontend_azure_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.frontend_base_cidr_block
  networks = [
    {
      name     = "vm"
      new_bits = 8
    },
    {
      name     = "azfw",
      new_bits = 8
    },
    {
      name     = "pe",
      new_bits = 8
    },
    {
      name     = "bastion",
      new_bits = 8
    },
  ]
}
resource "azurerm_virtual_network" "frontend" {
  name                = "vnet-azfwprem"
  resource_group_name = azurerm_resource_group.frontend.name
  location            = azurerm_resource_group.frontend.location
  address_space       = [module.frontend_azure_subnet_addrs.base_cidr_block]
}
resource "azurerm_subnet" "fe_vm" {
  name                 = "snet-vm"
  resource_group_name  = azurerm_resource_group.frontend.name
  virtual_network_name = azurerm_virtual_network.frontend.name
  address_prefixes     = [module.frontend_azure_subnet_addrs.network_cidr_blocks["vm"]]
}
resource "azurerm_subnet" "fe_azfw" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.frontend.name
  virtual_network_name = azurerm_virtual_network.frontend.name
  address_prefixes     = [module.frontend_azure_subnet_addrs.network_cidr_blocks["azfw"]]
  depends_on = [
    azurerm_subnet.fe_vm,
  ]
}
resource "azurerm_subnet" "pe" {
  name                 = "snet-pe"
  resource_group_name  = azurerm_resource_group.frontend.name
  virtual_network_name = azurerm_virtual_network.frontend.name
  address_prefixes     = [module.frontend_azure_subnet_addrs.network_cidr_blocks["pe"]]
  depends_on = [
    azurerm_subnet.fe_vm,
  ]
}
resource "azurerm_subnet" "fe_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.frontend.name
  virtual_network_name = azurerm_virtual_network.frontend.name
  address_prefixes     = [module.frontend_azure_subnet_addrs.network_cidr_blocks["bastion"]]
  depends_on = [
    azurerm_subnet.azfw,
  ]
}

resource "azurerm_private_endpoint" "example" {
  name                = "pe-to-backend-appgw"
  resource_group_name = azurerm_resource_group.frontend.name
  location            = azurerm_resource_group.frontend.location
  subnet_id           = azurerm_subnet.pe.id

  private_service_connection {
    name                           = "example-privateserviceconnection"
    private_connection_resource_id = azurerm_application_gateway.network.id
    subresource_names              = [local.frontend_ip_configuration_private_name]
    is_manual_connection           = false
  }
}

# --------------------------
# VM
# --------------------------
module "webserver" {
  source              = "../modules/vm-linux/"
  admin_username      = "adminuser"
  public_key          = var.ssh_public_key
  resource_group_name = azurerm_resource_group.frontend.name
  location            = azurerm_resource_group.frontend.location
  subnet_id           = azurerm_subnet.fe_vm.id
  name                = "vmfrontend"
  custom_data         = <<-EOF
  #cloud-config
    package_upgrade: true
    packages:
      - nginx
  EOF
}
module "fe_bastion" {
  source              = "../modules/bastion/"
  name                = "bastion-frontend"
  resource_group_name = azurerm_resource_group.frontend.name
  location            = azurerm_resource_group.frontend.location
  subnet_id           = azurerm_subnet.fe_bastion.id
}

resource "azurerm_network_security_group" "bastion" {
  name                = "nsg-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_network_security_rule" "bastion-https" {
  name                        = "AllowHttpsInbound"
  description                 = ""
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion.name
}
resource "azurerm_network_security_rule" "bastion-gwm" {
  name                                       = "AllowGatewayManagerInbound"
  description                                = ""
  priority                                   = 130
  direction                                  = "Inbound"
  access                                     = "Allow"
  protocol                                   = "Tcp"
  source_port_range                          = "*"
  destination_port_range                     = "443"
  source_address_prefix                      = "GatewayManager"
  destination_address_prefix                 = "*"
  source_application_security_group_ids      = []
  destination_application_security_group_ids = []
  resource_group_name                        = var.resource_group_name
  network_security_group_name                = azurerm_network_security_group.bastion.name
}
resource "azurerm_network_security_rule" "bastion-lb" {
  name                        = "AllowAzureLoadBalancerInbound"
  description                 = ""
  priority                    = 140
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion.name
}
resource "azurerm_network_security_rule" "bastion-hc" {
  name                        = "AllowBastionHostCommunication"
  description                 = ""
  priority                    = 150
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  destination_port_ranges     = ["8080", "5701"]
  source_port_range           = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion.name
}

resource "azurerm_network_security_rule" "bastion-sshrdp-out" {
  name                        = "AllowSshRdpOutbound"
  description                 = ""
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  destination_port_ranges     = ["22", "3389"]
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion.name
}
resource "azurerm_network_security_rule" "bastion-azurecloud-out" {
  name                        = "AllowAzureCloudOutbound"
  description                 = ""
  priority                    = 130
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  destination_port_ranges     = ["443"]
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureCloud"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion.name
}
resource "azurerm_network_security_rule" "bastion-bastioncommunication-out" {
  name                        = "AllowBastionCommunication"
  description                 = ""
  priority                    = 140
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  destination_port_ranges     = ["8080", "5701"]
  source_port_range           = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion.name
}
resource "azurerm_network_security_rule" "bastion-gsi-out" {
  name                        = "AllowGetSesssionInformation"
  description                 = ""
  priority                    = 150
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  destination_port_ranges     = ["80"]
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.bastion.name
}
resource "azurerm_subnet_network_security_group_association" "hub-bastion" {
  depends_on = [
    azurerm_network_security_rule.bastion-azurecloud-out,
    azurerm_network_security_rule.bastion-bastioncommunication-out,
    azurerm_network_security_rule.bastion-gsi-out,
    azurerm_network_security_rule.bastion-gwm,
    azurerm_network_security_rule.bastion-https,
    azurerm_network_security_rule.bastion-hc,
    azurerm_network_security_rule.bastion-lb,
    azurerm_network_security_rule.bastion-sshrdp-out,
  ]
  subnet_id                 = var.subnet_id
  network_security_group_id = azurerm_network_security_group.bastion.id
}

resource "azurerm_public_ip" "bastion" {
  name                = "pip-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  depends_on = [
    azurerm_subnet_network_security_group_association.hub-bastion
  ]

  name                   = var.name
  resource_group_name    = var.resource_group_name
  location               = var.location
  sku                    = "Standard"
  ip_connect_enabled     = true
  tunneling_enabled      = true
  shareable_link_enabled = true

  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_network_security_group" "nsg-aks" {
  name                = "nsg-aks"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
}

#resource "azurerm_network_security_rule" "nsg-aks-inbound-AllowPodCidr" {
  #name                        = "AllowPodCIDR"
  #priority                    = 4047
  #direction                   = "Inbound"
  #access                      = "Allow"
  #protocol                    = "*"
  #description                 = "For Pod CDIR"
  #source_port_range           = "*"
  #destination_port_range      = "*"
  #source_address_prefixes     = ["10.245.0.0/16"]
  #destination_address_prefix  = "VirtualNetwork"
  #resource_group_name         = azurerm_resource_group.example.name
  #network_security_group_name = azurerm_network_security_group.nsg-aks.name
#}

resource "azurerm_network_security_rule" "nsg-aks-inbound-AllowLB" {
  name                        = "AllowLB"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  description                 = "For Azure Load Balancer"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.example.name
  network_security_group_name = azurerm_network_security_group.nsg-aks.name
}

resource "azurerm_network_security_rule" "nsg-aks-inbound-AllowSameSubnet" {
  name                        = "AllowSameSubnet"
  priority                    = 4050
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  description                 = "For Self Subnet"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = azurerm_subnet.subnet-aks.address_prefixes
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.example.name
  network_security_group_name = azurerm_network_security_group.nsg-aks.name
}

resource "azurerm_network_security_rule" "nsg-aks-inbound-DenyAllinbound" {
  name                        = "DenyAllinbound"
  priority                    = 4051
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  description                 = "For Deny All"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.example.name
  network_security_group_name = azurerm_network_security_group.nsg-aks.name
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.subnet-aks.id
  network_security_group_id = azurerm_network_security_group.nsg-aks.id
}
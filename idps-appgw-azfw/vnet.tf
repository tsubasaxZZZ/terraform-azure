// ------------------------------------------
// VNet
// ------------------------------------------
resource "azurerm_virtual_network" "example" {
  name                = "vnet-example"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = [module.azure_subnet_addrs.base_cidr_block]
}

module "azure_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.base_cidr_block
  networks = [
    {
      name     = "default"
      new_bits = 8
    },
    {
      name     = "pls",
      new_bits = 8
    },
    {
      name     = "bastion",
      new_bits = 8
    },
    {
      name     = "azfw",
      new_bits = 8
    },
    {
      name     = "appgw",
      new_bits = 8
    },
    {
      name     = "default2",
      new_bits = 8
    }
  ]
}
resource "azurerm_subnet" "default" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = [module.azure_subnet_addrs.network_cidr_blocks["default"]]
}

resource "azurerm_subnet" "bastion" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.default,
  ]
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = [module.azure_subnet_addrs.network_cidr_blocks["bastion"]]
}

resource "azurerm_subnet" "pls" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.bastion,
  ]
  name                                          = "snet-pls"
  resource_group_name                           = azurerm_resource_group.example.name
  virtual_network_name                          = azurerm_virtual_network.example.name
  address_prefixes                              = [module.azure_subnet_addrs.network_cidr_blocks["pls"]]
  private_endpoint_network_policies_enabled     = false
  private_link_service_network_policies_enabled = false
}
resource "azurerm_subnet" "azfw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.pls,
  ]
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = [module.azure_subnet_addrs.network_cidr_blocks["azfw"]]
}
resource "azurerm_subnet" "appgw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.azfw,
  ]
  name                 = "snet-appgw"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = [module.azure_subnet_addrs.network_cidr_blocks["appgw"]]
}
resource "azurerm_subnet" "default2" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.appgw,
  ]
  name                 = "snet-default-backend-appgw"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = [module.azure_subnet_addrs.network_cidr_blocks["default2"]]
}

module "bastion" {
  source              = "../modules/bastion/"
  name                = "bastion"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.bastion.id
}

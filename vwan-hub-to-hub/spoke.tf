// ----------------------------------------
// East Network
// ----------------------------------------
module "azure_east_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.azure_east.spoke_base_cidr_block
  networks = [
    {
      name     = "default"
      new_bits = 8
    },
    {
      name     = "vpngw",
      new_bits = 8
    },
    {
      name     = "bastion",
      new_bits = 8
    },
    {
      name     = "routeserver",
      new_bits = 8
    },
    {
      name     = "azfw",
      new_bits = 8
    }
  ]
}
resource "azurerm_virtual_network" "east" {
  name                = "vnet-east"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_east.location
  address_space       = [module.azure_east_subnet_addrs.base_cidr_block]
}
resource "azurerm_subnet" "east_default" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.east.name
  address_prefixes     = [module.azure_east_subnet_addrs.network_cidr_blocks["default"]]
}

resource "azurerm_subnet" "east_bastion" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.east_default,
  ]
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.east.name
  address_prefixes     = [module.azure_east_subnet_addrs.network_cidr_blocks["bastion"]]
}

resource "azurerm_subnet" "east_vpngw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.east_bastion,
  ]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.east.name
  address_prefixes     = [module.azure_east_subnet_addrs.network_cidr_blocks["vpngw"]]
}

resource "azurerm_subnet" "east_azfw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.east_vpngw,
  ]
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.east.name
  address_prefixes     = [module.azure_east_subnet_addrs.network_cidr_blocks["azfw"]]
}

module "azfw_east" {
  source = "../modules/azurefirewall-premium"
  rg = {
    name     = azurerm_resource_group.example.name
    location = var.azure_east.location
  }
  id        = "east-spoke"
  subnet_id = azurerm_subnet.east_azfw.id
}
// ----------------------------------------
// East spoke Network
// ----------------------------------------
module "azure_east_spoke_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  count = var.azure_east_spokes == null ? 0 : length(var.azure_east_spokes)

  base_cidr_block = var.azure_east_spokes[count.index].spoke_base_cidr_block
  networks = [
    {
      name     = "default"
      new_bits = 8
    },
  ]
}
resource "azurerm_virtual_network" "east_spoke" {
  name = "vnet-east-spoke-${count.index}"

  count = var.azure_east_spokes == null ? 0 : length(var.azure_east_spokes)

  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_east.location
  address_space       = [module.azure_east_spoke_subnet_addrs[count.index].base_cidr_block]
}
resource "azurerm_subnet" "east_spoke_default" {
  name = "snet-default"

  count = var.azure_east_spokes == null ? 0 : length(var.azure_east_spokes)

  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.east_spoke[count.index].name
  address_prefixes     = [module.azure_east_spoke_subnet_addrs[count.index].network_cidr_blocks["default"]]
}

resource "azurerm_virtual_network_peering" "spoketohub" {
  name = "Spoke${count.index}ToHub"

  count = var.azure_east_spokes == null ? 0 : length(var.azure_east_spokes)

  resource_group_name       = azurerm_resource_group.example.name
  virtual_network_name      = azurerm_virtual_network.east_spoke[count.index].name
  remote_virtual_network_id = azurerm_virtual_network.east.id
  allow_forwarded_traffic   = true
}
resource "azurerm_virtual_network_peering" "hubtospoke" {
  name = "HubToSpoke${count.index}"

  count = var.azure_east_spokes == null ? 0 : length(var.azure_east_spokes)

  resource_group_name       = azurerm_resource_group.example.name
  virtual_network_name      = azurerm_virtual_network.east.name
  remote_virtual_network_id = azurerm_virtual_network.east_spoke[count.index].id
}

// ----------------------------------------
// East shared Network - connect to West
// ----------------------------------------
module "azure_east_shared_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.azure_east_shared.spoke_base_cidr_block
  networks = [
    {
      name     = "default"
      new_bits = 8
    },
    {
      name     = "vpngw",
      new_bits = 8
    },
    {
      name     = "bastion",
      new_bits = 8
    },
    {
      name     = "azfw",
      new_bits = 8
    }
  ]
}
resource "azurerm_virtual_network" "east_shared" {
  name                = "vnet-east-shared"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_east_shared.location
  address_space       = [module.azure_east_shared_subnet_addrs.base_cidr_block]
}
resource "azurerm_subnet" "east_shared_default" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.east_shared.name
  address_prefixes     = [module.azure_east_shared_subnet_addrs.network_cidr_blocks["default"]]
}

resource "azurerm_subnet" "east_shared_bastion" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.east_shared_default,
  ]
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.east_shared.name
  address_prefixes     = [module.azure_east_shared_subnet_addrs.network_cidr_blocks["bastion"]]
}

resource "azurerm_subnet" "east_shared_vpngw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.east_shared_bastion,
  ]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.east_shared.name
  address_prefixes     = [module.azure_east_shared_subnet_addrs.network_cidr_blocks["vpngw"]]
}

resource "azurerm_subnet" "east_shared_azfw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.east_shared_vpngw,
  ]
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.east_shared.name
  address_prefixes     = [module.azure_east_shared_subnet_addrs.network_cidr_blocks["azfw"]]
}

// ----------------------------------------
// West Network
// ----------------------------------------
module "azure_west_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.azure_west.spoke_base_cidr_block
  networks = [
    {
      name     = "default"
      new_bits = 8
    },
    {
      name     = "vpngw",
      new_bits = 8
    },
    {
      name     = "bastion",
      new_bits = 8
    },
    {
      name     = "routeserver",
      new_bits = 8
    },
    {
      name     = "azfw",
      new_bits = 8
    }
  ]
}
resource "azurerm_virtual_network" "west" {
  name                = "vnet-west"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_west.location
  address_space       = [module.azure_west_subnet_addrs.base_cidr_block]
}
resource "azurerm_subnet" "west_default" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.west.name
  address_prefixes     = [module.azure_west_subnet_addrs.network_cidr_blocks["default"]]
}

resource "azurerm_subnet" "west_bastion" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.west_default,
  ]
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.west.name
  address_prefixes     = [module.azure_west_subnet_addrs.network_cidr_blocks["bastion"]]
}

resource "azurerm_subnet" "west_vpngw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.west_bastion,
  ]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.west.name
  address_prefixes     = [module.azure_west_subnet_addrs.network_cidr_blocks["vpngw"]]
}

resource "azurerm_subnet" "west_azfw" {
  // workaround: operate subnets one after another
  // https://github.com/hashicorp/terraform-provider-azurerm/issues/3780
  depends_on = [
    azurerm_subnet.west_vpngw,
  ]
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.west.name
  address_prefixes     = [module.azure_west_subnet_addrs.network_cidr_blocks["azfw"]]
}

// ----------------------------------------
// VMs
// ----------------------------------------
module "vmeast_linux" {
  source              = "../modules/vm-linux"
  admin_username      = "azureuser"
  public_key          = var.ssh_public_key
  name                = "vmlinuxeast"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_east.location
  subnet_id           = azurerm_subnet.east_default.id
  custom_data         = <<EOF
#cloud-config
packages_update: true
packages_upgrade: true
runcmd:
  - apt install -y nginx
EOF
}

module "vmwest_linux" {
  source              = "../modules/vm-linux"
  admin_username      = "azureuser"
  public_key          = var.ssh_public_key
  name                = "vmlinuxwest"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_west.location
  subnet_id           = azurerm_subnet.west_default.id
  custom_data         = <<EOF
#cloud-config
packages_update: true
packages_upgrade: true
runcmd:
  - apt install -y nginx
EOF
}

module "vmeast_shared_linux" {
  source              = "../modules/vm-linux"
  admin_username      = "azureuser"
  public_key          = var.ssh_public_key
  name                = "vmlinuxeastshared"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_east_shared.location
  subnet_id           = azurerm_subnet.east_shared_default.id
  custom_data         = <<EOF
#cloud-config
packages_update: true
packages_upgrade: true
runcmd:
  - apt install -y nginx
EOF
}

module "vmeast_spoke_linux" {
  source = "../modules/vm-linux"

  count = var.azure_east_spokes == null ? 0 : length(var.azure_east_spokes)

  admin_username      = "azureuser"
  public_key          = var.ssh_public_key
  name                = "vmlinuxeastspoke${count.index}"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_east.location
  subnet_id           = azurerm_subnet.east_spoke_default[count.index].id
  custom_data         = <<EOF
#cloud-config
packages_update: true
packages_upgrade: true
runcmd:
  - apt install -y nginx
EOF
}

// --- Azure Bastion ---
module "bastion_east" {
  source              = "../modules/bastion/"
  name                = "bastion-east"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_east.location
  subnet_id           = azurerm_subnet.east_bastion.id
}

module "bastion_west" {
  source              = "../modules/bastion/"
  name                = "bastion-west"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_west.location
  subnet_id           = azurerm_subnet.west_bastion.id
}

// --------------
// East
// --------------
module "vm_nva_east" {
  source              = "../modules/vm-linux"
  admin_username      = "azureuser"
  public_key          = var.ssh_public_key
  name                = "vmnvaeast"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_east.location
  subnet_id           = azurerm_subnet.east_default.id
  custom_data         = <<EOF
#cloud-config
packages_update: true
packages_upgrade: true
runcmd:
  - sed -i.org 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  - sysctl -p
  - curl -s https://deb.frrouting.org/frr/keys.asc | apt-key add -
  - FRRVER="frr-stable"
  - echo deb https://deb.frrouting.org/frr $(lsb_release -s -c) $FRRVER | tee -a /etc/apt/sources.list.d/frr.list
  - apt update && apt -y install frr frr-pythontools
  - sed -i.org 's/bgpd=no/bgpd=yes/' /etc/frr/daemons
  - systemctl restart frr
EOF
}
resource "azurerm_public_ip" "ars_east" {
  name                = "pip-ars-east"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_east.location
  sku                 = "Standard"
  allocation_method   = "Static"
}
resource "azurerm_route_server" "east" {
  name                = "rs-east"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_east.location

  depends_on = [
    module.vngw_east,
  ]

  sku                              = "Standard"
  public_ip_address_id             = azurerm_public_ip.ars_east.id
  subnet_id                        = azurerm_subnet.east_routeserver.id
  branch_to_branch_traffic_enabled = true
}
resource "azurerm_route_server_bgp_connection" "east" {
  name            = "example-rs-bgpconnection"
  route_server_id = azurerm_route_server.east.id
  peer_asn        = 65001
  peer_ip         = module.vm_nva_east.network_interface_ipconfiguration.0.private_ip_address
}

// --------------
// West
// --------------
module "vm_nva_west" {
  source              = "../modules/vm-linux"
  admin_username      = "azureuser"
  public_key          = var.ssh_public_key
  name                = "vmnvawest"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_west.location
  subnet_id           = azurerm_subnet.west_default.id
  custom_data         = <<EOF
#cloud-config
packages_update: true
packages_upgrade: true
runcmd:
  - sed -i.org 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  - sysctl -p
  - curl -s https://deb.frrouting.org/frr/keys.asc | apt-key add -
  - FRRVER="frr-stable"
  - echo deb https://deb.frrouting.org/frr $(lsb_release -s -c) $FRRVER | tee -a /etc/apt/sources.list.d/frr.list
  - apt update && apt -y install frr frr-pythontools
  - sed -i.org 's/bgpd=no/bgpd=yes/' /etc/frr/daemons
  - systemctl restart frr
EOF
}
resource "azurerm_public_ip" "ars_west" {
  name                = "pip-ars-west"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_west.location
  sku                 = "Standard"
  allocation_method   = "Static"
}
resource "azurerm_route_server" "west" {
  name                = "rs-west"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.azure_west.location

  depends_on = [
    module.vngw_west,
  ]

  sku                              = "Standard"
  public_ip_address_id             = azurerm_public_ip.ars_west.id
  subnet_id                        = azurerm_subnet.west_routeserver.id
  branch_to_branch_traffic_enabled = true
}
resource "azurerm_route_server_bgp_connection" "west" {
  name            = "example-rs-bgpconnection"
  route_server_id = azurerm_route_server.west.id
  peer_asn        = 65001
  peer_ip         = module.vm_nva_west.network_interface_ipconfiguration.0.private_ip_address
}

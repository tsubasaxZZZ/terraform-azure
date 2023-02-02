module "nva" {
  source              = "../modules/vm-linux"
  admin_username      = "azureuser"
  public_key          = var.ssh_public_key
  name                = "vmnva"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = azurerm_subnet.default.id
  custom_data         = <<EOF
#cloud-config
packages_update: true
packages_upgrade: true
packages:
  - squid
runcmd:
  - sed -i.org 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  - sysctl -p
  - curl -s https://deb.frrouting.org/frr/keys.asc | apt-key add -
  - FRRVER="frr-stable"
  - echo deb https://deb.frrouting.org/frr $(lsb_release -s -c) $FRRVER | tee -a /etc/apt/sources.list.d/frr.list
  - apt update && apt -y install frr frr-pythontools
  - sed -i.org 's/bgpd=no/bgpd=yes/' /etc/frr/daemons
  - curl -L ${var.frr_config_url} -o /etc/frr/frr.conf
  - systemctl restart frr
  - sudo sed -i.org 's/#http_access allow localnet/http_access allow localnet/' /etc/squid/squid.conf
  - sudo sed -i.org.2 -r 's/^#(acl localnet)/\1/g' /etc/squid/squid.conf
  - systemctl restart squid
EOF
}
resource "azurerm_public_ip" "ars" {
  name                = "pip-ars"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Standard"
  allocation_method   = "Static"
}
resource "azurerm_route_server" "example" {
  name                = "rs-example"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  sku                              = "Standard"
  public_ip_address_id             = azurerm_public_ip.ars.id
  subnet_id                        = azurerm_subnet.routeserver.id
  branch_to_branch_traffic_enabled = true
}
resource "azurerm_route_server_bgp_connection" "example" {
  name            = "example-rs-bgpconnection"
  route_server_id = azurerm_route_server.example.id
  peer_asn        = var.nva_bgp_asn
  peer_ip         = module.nva.network_interface_ipconfiguration.0.private_ip_address
}

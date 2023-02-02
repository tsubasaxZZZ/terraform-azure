# --------------------------
# VM
# --------------------------
module "vm" {
  count = var.numberOfVMs
  source              = "../modules/vm-linux/"
  admin_username      = "adminuser"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "vm${count.index}"
  subnet_id           = azurerm_subnet.default.id
  public_key          = var.ssh_public_key
  custom_data         = <<EOF
#cloud-config
packages_update: true
packages_upgrade: true
packages:
  - nginx
runcmd:
  - echo "<h1>vm${count.index}</h1>" | tee /var/www/html/index.nginx-debian.html
EOF
}

// PLS
locals {
  pls_private_address = cidrhost(module.azure_subnet_addrs.network_cidr_blocks["pls"], 4)
}
resource "azurerm_private_link_service" "example" {
  name                = "pls-example"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  nat_ip_configuration {
    name               = "primary"
    subnet_id          = azurerm_subnet.pls.id
    primary            = true
    private_ip_address = local.pls_private_address
  }

  load_balancer_frontend_ip_configuration_ids = [
    azurerm_lb.example.frontend_ip_configuration.0.id,
  ]
}

// Load Balancer
resource "azurerm_lb" "example" {
  name                = "lb-example"
  sku                 = "Standard"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  frontend_ip_configuration {
    name                          = "frontendip"
    subnet_id                     = azurerm_subnet.default.id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_lb_backend_address_pool" "example" {
  loadbalancer_id = azurerm_lb.example.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "example" {
  loadbalancer_id = azurerm_lb.example.id
  name            = "probe"
  port            = 80
}

resource "azurerm_lb_rule" "example" {
  loadbalancer_id                = azurerm_lb.example.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.example.frontend_ip_configuration.0.name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.example.id]
  probe_id                       = azurerm_lb_probe.example.id
  idle_timeout_in_minutes        = 15
  load_distribution              = "Default" //SourceIP or SourceIPProtocol
  enable_tcp_reset               = false
}

resource "azurerm_network_interface_backend_address_pool_association" "example" {
  count = length(module.vm)

  network_interface_id    = module.vm[count.index].network_interface_id
  ip_configuration_name   = module.vm[count.index].network_interface_ipconfiguration.0.name
  backend_address_pool_id = azurerm_lb_backend_address_pool.example.id
}

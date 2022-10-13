# --------------------------
# Networking
# --------------------------
resource "azurerm_virtual_network" "pl" {
  name                = "vnet-backend"
  address_space       = ["10.1.0.0/16"]
  resource_group_name = var.rg.name
  location            = var.rg.location
}

resource "azurerm_subnet" "be_default" {
  name                                          = "snet-default"
  resource_group_name                           = var.rg.name
  virtual_network_name                          = azurerm_virtual_network.pl.name
  address_prefixes                              = ["10.1.0.0/24"]
  enforce_private_link_service_network_policies = true
}
resource "azurerm_subnet" "be_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.rg.name
  virtual_network_name = azurerm_virtual_network.pl.name
  address_prefixes     = ["10.1.100.0/24"]
}
resource "azurerm_private_link_service" "example" {
  name                = "pls-backend"
  resource_group_name = var.rg.name
  location            = var.rg.location

  nat_ip_configuration {
    name                       = "primary"
    private_ip_address         = "10.1.0.5"
    private_ip_address_version = "IPv4"
    subnet_id                  = azurerm_subnet.be_default.id
    primary                    = true
  }

  load_balancer_frontend_ip_configuration_ids = [
    azurerm_lb.example.frontend_ip_configuration.0.id,
  ]
}

// Load Balancer
resource "azurerm_lb" "example" {
  name                = "lb-backend"
  sku                 = "Standard"
  resource_group_name = var.rg.name
  location            = var.rg.location

  frontend_ip_configuration {
    name                          = "frontendip"
    subnet_id                     = azurerm_subnet.be_default.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.1.0.4"
  }
}
resource "azurerm_lb_backend_address_pool" "example" {
  loadbalancer_id = azurerm_lb.example.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "example" {
  loadbalancer_id = azurerm_lb.example.id
  name            = "probehttp"
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
# --------------------------
# VM
# --------------------------
module "vm" {
  source                        = "../modules/vm-linux"
  admin_username                = "azureuser"
  public_key                    = var.ssh_public_key
  name                          = "vmbackend"
  resource_group_name           = var.rg.name
  location                      = var.rg.location
  subnet_id                     = azurerm_subnet.be_default.id
  private_ip_address_allocation = "Static"
  private_ip_address            = "10.1.0.6"
  zone                          = 1
  custom_data                   = <<EOF
#!/bin/bash
sudo apt-get update
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io nginx
sudo usermod -aG docker ${var.admin_username}
sudo apt-get install -y openjdk-11-jdk
EOF
}
resource "azurerm_network_interface_backend_address_pool_association" "example" {
  network_interface_id    = module.vm.network_interface_id
  ip_configuration_name   = module.vm.network_interface_ipconfiguration.0.name
  backend_address_pool_id = azurerm_lb_backend_address_pool.example.id
}
module "be_bastion" {
  source              = "../modules/bastion/"
  name                = "bastion-be"
  resource_group_name = var.rg.name
  location            = var.rg.location
  subnet_id           = azurerm_subnet.be_bastion.id
}

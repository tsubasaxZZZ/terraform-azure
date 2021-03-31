variable "resource_group_name" {
}
variable "source_address_prefix_for_nsg" {
  default = "*"
}
variable "location" {
}
variable "ssh_key_path" {
}
variable "admin_username" {
}

terraform {
  required_version = "~> 0.14.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.53.0"
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
    resource_group_name = var.resource_group_name
  }
}

resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name
  location = var.location
}

#####################################
# Frontend
#####################################

// VNet
resource "azurerm_virtual_network" "pe" {
  name                = "myVNetPE"
  address_space       = ["10.11.0.0/16"]
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
}

resource "azurerm_subnet" "fe_bastion" {
  name                 = "myBastionSubnetPE"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.pe.name
  address_prefixes     = ["10.11.100.0/24"]
}
resource "azurerm_subnet" "fe_pe" {
  name                                           = "mySubnetPE"
  resource_group_name                            = azurerm_resource_group.example.name
  virtual_network_name                           = azurerm_virtual_network.pe.name
  address_prefixes                               = ["10.11.0.0/24"]
  enforce_private_link_endpoint_network_policies = true
}

// VM
module "frontend_vm" {
  source                = "../modules/vm-linux"
  admin_username        = var.admin_username
  public_key            = file(var.ssh_key_path)
  name                  = "privateendpoint-bastion-vm"
  resource_group_name   = azurerm_resource_group.example.name
  location              = azurerm_resource_group.example.location
  subnet_id             = azurerm_subnet.fe_bastion.id
  source_address_prefix = var.source_address_prefix_for_nsg
  zone                  = 1
  custom_data           = <<EOF
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
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker ${var.admin_username}
sudo apt-get install -y openjdk-11-jdk
cd /opt
sudo wget https://downloads.apache.org//jmeter/binaries/apache-jmeter-5.4.1.tgz
sudo tar zxvf apache-jmeter-5.1.1.tgz
EOF
}

resource "azurerm_private_endpoint" "example" {
  name                = "myPrivateEndpoint"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  subnet_id           = azurerm_subnet.fe_pe.id

  private_service_connection {
    name                           = "example-privateserviceconnection"
    private_connection_resource_id = azurerm_private_link_service.example.id
    is_manual_connection           = false
  }
}

#####################################
# Backend
#####################################
resource "azurerm_virtual_network" "pl" {
  name                = "myVNet"
  address_space       = ["10.1.0.0/16"]
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
}

resource "azurerm_subnet" "be_default" {
  name                                          = "mySubnet"
  resource_group_name                           = azurerm_resource_group.example.name
  virtual_network_name                          = azurerm_virtual_network.pl.name
  address_prefixes                              = ["10.1.0.0/24"]
  enforce_private_link_service_network_policies = true
}
resource "azurerm_subnet" "be_bastion" {
  name                 = "myBastionSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.pl.name
  address_prefixes     = ["10.1.100.0/24"]
}
resource "azurerm_private_link_service" "example" {
  name                = "myPrivateLinkService"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

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
  name                = "myLoadBalancer"
  sku                 = "Standard"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

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
  resource_group_name = azurerm_resource_group.example.name
  loadbalancer_id     = azurerm_lb.example.id
  name                = "api"
  port                = 8080
}

resource "azurerm_lb_rule" "example" {
  resource_group_name            = azurerm_resource_group.example.name
  loadbalancer_id                = azurerm_lb.example.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  frontend_ip_configuration_name = azurerm_lb.example.frontend_ip_configuration.0.name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.example.id
  probe_id                       = azurerm_lb_probe.example.id
  idle_timeout_in_minutes        = 15
  load_distribution              = "Default" //SourceIP or SourceIPProtocol 
  enable_tcp_reset               = false
}

// API VM
module "api_vm" {
  source                        = "../modules/vm-linux"
  admin_username                = var.admin_username
  public_key                    = file(var.ssh_key_path)
  name                          = "apivm01"
  resource_group_name           = azurerm_resource_group.example.name
  location                      = azurerm_resource_group.example.location
  subnet_id                     = azurerm_subnet.be_default.id
  source_address_prefix         = var.source_address_prefix_for_nsg
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
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker ${var.admin_username}
sudo apt-get install -y openjdk-11-jdk
EOF
}
resource "azurerm_network_interface_backend_address_pool_association" "example" {
  network_interface_id    = module.api_vm.network_interface_id
  ip_configuration_name   = module.api_vm.network_interface_ipconfiguration.0.name
  backend_address_pool_id = azurerm_lb_backend_address_pool.example.id
}

// Test VM
module "test_vm" {
  source                = "../modules/vm-linux"
  admin_username        = var.admin_username
  public_key            = file(var.ssh_key_path)
  name                  = "privatelink-bastion-vm"
  resource_group_name   = azurerm_resource_group.example.name
  location              = azurerm_resource_group.example.location
  subnet_id             = azurerm_subnet.be_bastion.id
  source_address_prefix = var.source_address_prefix_for_nsg
  zone                  = 1
  custom_data           = <<EOF
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
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker ${var.admin_username}
sudo apt-get install -y openjdk-11-jdk
cd /opt
sudo wget https://downloads.apache.org//jmeter/binaries/apache-jmeter-5.4.1.tgz
sudo tar zxvf apache-jmeter-5.1.1.tgz
EOF
}

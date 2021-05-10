source "azure-arm" "zabbix-server" {
  use_azure_cli_auth                = true
  image_publisher                   = "Canonical"
  image_offer                       = "UbuntuServer"
  image_sku                         = "18.04-LTS"
  managed_image_name                = "UbuntuServer-zabbix-server"
  managed_image_resource_group_name = "rg-iacpoc"
  managed_image_zone_resilient      = true
  location                          = "japaneast"
  temp_resource_group_name          = "rg-iacpoc-temp-server"
  vm_size                           = "Standard_B2ms"
  os_type                           = "Linux"
}
source "azure-arm" "zabbix-client" {
  use_azure_cli_auth                = true
  image_publisher                   = "Canonical"
  image_offer                       = "UbuntuServer"
  image_sku                         = "18.04-LTS"
  managed_image_name                = "UbuntuServer-zabbix-client"
  managed_image_resource_group_name = "rg-iacpoc"
  managed_image_zone_resilient      = true
  location                          = "japaneast"
  temp_resource_group_name          = "rg-iacpoc-temp-client"
  vm_size                           = "Standard_B2ms"
  os_type                           = "Linux"
}

build {
  sources = ["sources.azure-arm.zabbix-server"]
  provisioner "ansible" {
    playbook_file       = "./playbook/site.yaml"
    galaxy_file         = "./playbook/requirements.yaml"
    groups              = ["zabbix_servers"]
  }
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
    inline_shebang = "/bin/sh -x"
  }
}

build {
  sources = ["sources.azure-arm.zabbix-client"]
  provisioner "ansible" {
    playbook_file       = "./playbook/site.yaml"
    galaxy_file         = "./playbook/requirements.yaml"
    groups              = ["zabbix_clients"]
  }
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
    inline_shebang = "/bin/sh -x"
  }
}

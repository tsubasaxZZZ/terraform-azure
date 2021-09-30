terraform {
  required_version = "~> 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.76.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_public_ip" "example" {
  name                = var.pip_name_for_apim
  resource_group_name = var.resource_group_name
}

resource "azurerm_resource_group_template_deployment" "example" {
  name                = "example-deploy"
  resource_group_name = var.resource_group_name
  deployment_mode     = "Incremental"
  parameters_content = jsonencode({
    "apimName" = {
      "value" = var.apim_name
    },
    "publisherEmail" = {
      value = "apim@example.com"
    },
    "publisherName" = {
      value = "contoso IT"
    },
    "virtualNetworkName" = {
      value = var.vnet_name
    },
    "subnetName" = {
      value = var.subnet_name_for_apim
    },
    "skuCount" = {
      value = var.apim_sku_count
    },
    "availabilityZones" = {
      value = var.apim_zones
    },
    "publicIpAddressId" = {
      value = data.azurerm_public_ip.example.id
    }
  })

  template_content = file("${path.module}/azuredeploy.json")
}

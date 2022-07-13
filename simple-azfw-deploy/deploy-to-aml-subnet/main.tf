terraform {
  required_version = "~> 1.2.1"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "azurerm" {
  //use_oidc = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

module "azfw" {
  source    = "../"
  rg        = var.rg
  id        = var.id
  subnet_id = var.subnet_id


  azurefirewall_application_rule = [{
    name     = "AllowApplicationRuleCollection"
    priority = 2000
    action   = "Allow"
    rule = [
      {
        name                  = "forAzureML"
        destination_addresses = []
        destination_fqdn_tags = []
        destination_fqdns = [
          "graph.windows.net",
          "anaconda.com",
          "*.anaconda.com",
          "pypi.org",
          "cloud.r-project.org",
          "*pytorch.org",
          "*.tensorflow.org",
          "raw.githubusercontent.com",
          "dc.applicationinsights.azure.com",
          "dc.applicationinsights.microsoft.com",
          "dc.services.visualstudio.com",
          "update.code.visualstudio.com",
          "*.vo.msecnd.net",
        ]
        destination_urls = []
        protocols = [
          {
            port = 80
            type = "Http"
          },
          {
            port = 443
            type = "Https"
          }
        ]
        source_addresses = [var.source_ip_range]
        source_ip_groups = []
        terminate_tls    = false
        web_categories   = []
      }
    ]
  }]

  azurefirewall_network_rule = [{
    action   = "Allow"
    name     = "AllowNetworkRuleCollection"
    priority = 1000
    rule = [
      /*
      {
        name                  = "All"
        source_addresses      = [var.source_ip_range]
        protocols             = ["TCP"]
        destination_ports     = ["*"]
        destination_addresses = ["*"]
        destination_fqdns     = []

      },
      */
      {
        name                  = "AzureActiveDirectory"
        source_addresses      = [var.source_ip_range]
        protocols             = ["TCP"]
        destination_ports     = ["80", "443"]
        destination_addresses = ["AzureActiveDirectory"]
        destination_fqdns     = []
      },
      {
        name                  = "AzureMachineLearning"
        source_addresses      = [var.source_ip_range]
        protocols             = ["TCP"]
        destination_ports     = ["443", "8787", "18881"]
        destination_addresses = ["AzureMachineLearning"]
        destination_fqdns     = []
      },
      {
        name                  = "AzureResourceManager"
        source_addresses      = [var.source_ip_range]
        protocols             = ["TCP"]
        destination_ports     = ["80", "443"]
        destination_addresses = ["AzureResourceManager"]
        destination_fqdns     = []
      },
      {
        name                  = "Storage.japaneast"
        source_addresses      = [var.source_ip_range]
        protocols             = ["TCP"]
        destination_ports     = ["80", "443"]
        destination_addresses = ["Storage.JapanEast"]
        destination_fqdns     = []
      },
      {
        name                  = "AzureFrontDoor.Frontend"
        source_addresses      = [var.source_ip_range]
        protocols             = ["TCP"]
        destination_ports     = ["80", "443"]
        destination_addresses = ["AzureFrontDoor.Frontend"]
        destination_fqdns     = []
      },
      {
        name                  = "AzureContainerRegistry.JapanEast"
        source_addresses      = [var.source_ip_range]
        protocols             = ["TCP"]
        destination_ports     = ["80", "443"]
        destination_addresses = ["AzureContainerRegistry.JapanEast"]
        destination_fqdns     = []
      },
      {
        name                  = "MicrosoftContainerRegistry"
        source_addresses      = [var.source_ip_range]
        protocols             = ["TCP"]
        destination_ports     = ["80", "443"]
        destination_addresses = ["MicrosoftContainerRegistry"]
        destination_fqdns     = []
      },
      {
        name                  = "AzureKeyVault"
        source_addresses      = [var.source_ip_range]
        protocols             = ["TCP"]
        destination_ports     = ["80", "443"]
        destination_addresses = ["AzureKeyVault"]
        destination_fqdns     = []
      },
      {
        name                  = "AzureFrontDoor.FirstParty"
        source_addresses      = [var.source_ip_range]
        protocols             = ["TCP"]
        destination_ports     = ["80", "443"]
        destination_addresses = ["AzureFrontDoor.FirstParty"]
        destination_fqdns     = []
      },
      {
        name                  = "AzureMonitor"
        source_addresses      = [var.source_ip_range]
        protocols             = ["TCP"]
        destination_ports     = ["80", "443"]
        destination_addresses = ["AzureMonitor"]
        destination_fqdns     = []
      },
    ]
  }]
}

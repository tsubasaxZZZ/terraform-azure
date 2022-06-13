locals {
  firewall = {
    name = "fw-${var.id}"
  }
}

resource "azurerm_public_ip" "example" {
  name                = "pip-${local.firewall.name}"
  location            = var.rg.location
  resource_group_name = var.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

/*
resource "azurerm_user_assigned_identity" "example" {
  resource_group_name = var.rg.name
  location            = var.rg.location
  name                = "id-cert-${local.firewall.name}"
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "example" {
  name                       = "kv-${local.firewall.name}"
  resource_group_name        = var.rg.name
  location                   = var.rg.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  sku_name = "standard"

  access_policy = [
    {
      tenant_id      = data.azurerm_client_config.current.tenant_id
      object_id      = azurerm_user_assigned_identity.example.principal_id
      application_id = null

      key_permissions = [
      ]

      secret_permissions = [
        "List",
        "Get",
      ]

      certificate_permissions = [
        "List",
        "Get"
      ]

      storage_permissions = [
      ]
    },
    {
      tenant_id      = data.azurerm_client_config.current.tenant_id
      object_id      = data.azurerm_client_config.current.object_id
      application_id = null

      key_permissions = [
      ]

      secret_permissions = [
        "Set",
        "List",
        "Get",
        "Delete",
        "Purge",
      ]

      certificate_permissions = [
        "Create",
        "List",
        "Get",
        "Delete",
        "Recover",
        "Update",
        "Purge",
      ]

      storage_permissions = [
      ]
    }
  ]
}

resource "azurerm_key_vault_certificate" "example" {
  name         = "generated-cert"
  key_vault_id = azurerm_key_vault.example.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        lifetime_percentage = 80
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      # Server Authentication = 1.3.6.1.5.5.7.3.1
      # Client Authentication = 1.3.6.1.5.5.7.3.2
      extended_key_usage = ["1.3.6.1.5.5.7.3.1", "1.3.6.1.5.5.7.3.2"]

      key_usage = [
        "digitalSignature",
        "keyCertSign",
        "cRLSign",
      ]

      subject            = "CN=Azure Firewall"
      validity_in_months = 12
    }
  }
}
*/
resource "azurerm_firewall_policy" "example" {
  name                = "afwp-${var.id}"
  location            = var.rg.location
  resource_group_name = var.rg.name
  sku                 = "Premium"
  /*
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.example.id]
  }
  tls_certificate {
    key_vault_secret_id = azurerm_key_vault_certificate.example.secret_id
    name                = "generated-cert"
  }
*/
}

resource "azurerm_firewall" "example" {
  name                = "afw-${var.id}"
  location            = var.rg.location
  resource_group_name = var.rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Premium"
  zones               = ["1", "2", "3"]
  firewall_policy_id  = azurerm_firewall_policy.example.id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.example.id
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "example" {
  name               = "HubSpokeCollection"
  firewall_policy_id = azurerm_firewall_policy.example.id
  priority           = 1000

  dynamic "network_rule_collection" {
    for_each = var.azurefirewall_network_rule
    content {
      name     = network_rule_collection.value.name
      priority = network_rule_collection.value.priority
      action   = network_rule_collection.value.action
      dynamic "rule" {
        for_each = network_rule_collection.value.rule
        content {
          name                  = rule.value.name
          protocols             = rule.value.protocols
          source_addresses      = rule.value.source_addresses
          destination_addresses = rule.value.destination_addresses
          destination_ports     = rule.value.destination_ports
        }
      }
    }
  }
}

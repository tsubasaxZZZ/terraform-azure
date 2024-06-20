provider "azurerm" {
  features {}
}

resource "random_string" "uniqstr" {
  length  = 6
  special = false
  upper   = false
  keepers = {
    resource_group_name = var.rg.name
  }
}
# リソースグループの作成
resource "azurerm_resource_group" "example" {
  name     = var.rg.name
  location = var.rg.location
}

# Cognitive Servicesアカウントの作成
resource "azurerm_cognitive_account" "documentinteligence" {
  name                = "di-example"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  kind                = "FormRecognizer"
  sku_name            = "S0"

  custom_subdomain_name = "di${random_string.uniqstr.result}"

}

resource "azurerm_search_service" "example" {
  name                = "aisearch-${random_string.uniqstr.result}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "standard"

  local_authentication_enabled = true
  authentication_failure_mode  = "http403"

  identity {
    type = "SystemAssigned"
  }
}
resource "azurerm_storage_account" "data" {
  name                     = "datasa${random_string.uniqstr.result}"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.data.name
  container_access_type = "private"
}

# Azure OpenAI Service Account
resource "azurerm_cognitive_account" "openai" {
  name                  = "openai-${random_string.uniqstr.result}"
  resource_group_name   = azurerm_resource_group.example.name
  location              = azurerm_resource_group.example.location
  kind                  = "OpenAI"
  sku_name              = "S0"
  custom_subdomain_name = "aoai${random_string.uniqstr.result}"
  network_acls {
    default_action = "Deny"
    ip_rules       = []
  }
}

# Add role to AI Search as Cognitive Services OpenAI User
resource "azurerm_role_assignment" "openai_user_assignment" {
  principal_id         = azurerm_search_service.example.identity[0].principal_id
  role_definition_name = "Cognitive Services OpenAI User"
  scope                = azurerm_cognitive_account.openai.id
}

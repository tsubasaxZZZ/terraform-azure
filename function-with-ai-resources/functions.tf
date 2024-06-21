# ストレージアカウントの作成
resource "azurerm_storage_account" "example" {
  name                     = "funcsa${random_string.uniqstr.result}"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "example" {
  name                  = "function-code"
  storage_account_name  = azurerm_storage_account.example.name
  container_access_type = "private"
}

# App Serviceプランの作成
resource "azurerm_service_plan" "example" {
  name                = "appserviceplan-${random_string.uniqstr.result}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  os_type             = "Linux"
  sku_name            = "P1v2"
}

resource "azurerm_linux_function_app" "example" {
  name                = "func-${random_string.uniqstr.result}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  storage_account_name                           = azurerm_storage_account.example.name
  storage_account_access_key                     = azurerm_storage_account.example.primary_access_key
  service_plan_id                                = azurerm_service_plan.example.id
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = 3.11
    }
    app_service_logs {
    }
    
    application_insights_connection_string = azurerm_application_insights.example.connection_string
  }

}
# FunctionsのManaged Identityに対してDocument Intelligenceの "Cognitive Service User" ロールを割り当てる
resource "azurerm_role_assignment" "cognitive_service_user_assignment" {
  principal_id         = azurerm_linux_function_app.example.identity[0].principal_id
  role_definition_name = "Cognitive Services User"
  scope                = azurerm_cognitive_account.documentinteligence.id
}


# Create App Insights with Log Analtyics
resource "azurerm_application_insights" "example" {
  name                = "ai-${random_string.uniqstr.result}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.example.id
}

resource "azurerm_log_analytics_workspace" "example" {
  name                = "la-${random_string.uniqstr.result}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

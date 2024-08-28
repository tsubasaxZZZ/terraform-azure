
# Document Intelligence
resource "azurerm_cognitive_account" "documentinteligence" {
  name                       = "di-${random_string.uniqstr.result}-1"
  resource_group_name        = azurerm_resource_group.example.name
  location                   = "eastus" //azurerm_resource_group.example.location
  kind                       = "FormRecognizer"
  sku_name                   = "S0"
  dynamic_throttling_enabled = true

  custom_subdomain_name = "di${random_string.uniqstr.result}-1"

  identity {
    type = "SystemAssigned"
  }

  network_acls {
    default_action = "Allow"
    ip_rules       = []
  }

  local_auth_enabled = false
}

# Azure AI Search
resource "azurerm_search_service" "example" {
  name                = "aisearch-${random_string.uniqstr.result}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "basic"

  local_authentication_enabled = true
  authentication_failure_mode  = "http403"

  identity {
    type = "SystemAssigned"
  }
}

# Storage Account for AI Search
resource "azurerm_storage_account" "data" {
  name                     = "datasa${random_string.uniqstr.result}"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  # Restrict Network only from trusted services
  network_rules {
    default_action = "Deny"
    ip_rules = [
      data.http.my_public_ip.response_body
    ]
    virtual_network_subnet_ids = []
    bypass                     = ["AzureServices"]
  }
}

// Get local IP address by using local resource with `curl ifconfig.me` command
data "http" "my_public_ip" {
  url = "https://api.ipify.org"
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.data.name
  container_access_type = "private"
}


# Add role to Storage Account for Document Intelligence and AI Search as Storage Blob Data Reader
resource "azurerm_role_assignment" "data_storage_blob_data_reader_assignment_to_di" {
  principal_id         = azurerm_cognitive_account.documentinteligence.identity[0].principal_id
  role_definition_name = "Storage Blob Data Reader"
  scope                = azurerm_storage_account.data.id
}
resource "azurerm_role_assignment" "data_storage_blob_data_reader_assignment_to_aisearch" {
  principal_id         = azurerm_search_service.example.identity[0].principal_id
  role_definition_name = "Storage Blob Data Reader"
  scope                = azurerm_storage_account.data.id
}

# Azure OpenAI Service
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

resource "azurerm_cognitive_deployment" "example" {
  name                   = "my-text-embedding-ada-002-model"
  cognitive_account_id   = azurerm_cognitive_account.openai.id
  rai_policy_name        = "Microsoft.DefaultV2"
  version_upgrade_option = "OnceNewDefaultVersionAvailable"
  model {
    format = "OpenAI"
    name   = "text-embedding-ada-002"
  }

  scale {
    type     = "Standard"
    capacity = 120
  }
}

# Add role to AI Search as Cognitive Services OpenAI User
resource "azurerm_role_assignment" "openai_user_assignment" {
  principal_id         = azurerm_search_service.example.identity[0].principal_id
  role_definition_name = "Cognitive Services OpenAI User"
  scope                = azurerm_cognitive_account.openai.id
}

locals {
  skillset_name   = "my-skillset"
  datasource_name = "my-datasource"
  index_name      = "my-index"
  indexer_name    = "my-indexer"
}
// Update index by using null_resource
data "template_file" "index" {
  template = file("${path.module}/aisearch/index.json")
  vars = {
    index_name = local.index_name
  }
}
resource "null_resource" "create_index" {
  triggers = {
    always_run = timestamp()
    //file_changed = md5(data.template_file.index.rendered)
  }
  provisioner "local-exec" {
    command = <<-EOT
      curl -v -X PUT \
      -H "Content-Type: application/json" \
      -H "api-key: ${nonsensitive(azurerm_search_service.example.primary_key)}" \
      -d '${data.template_file.index.rendered}' \
      "https://${azurerm_search_service.example.name}.search.windows.net/indexes/${local.index_name}?api-version=2024-07-01"
    EOT
  }
}

// Update skillset by using null_resource
data "azurerm_function_app_host_keys" "example" {
  name                = azurerm_linux_function_app.example.name
  resource_group_name = azurerm_resource_group.example.name
}
data "template_file" "skillset" {
  template = file("${path.module}/aisearch/skillset.json")
  vars = {
    skillset_name     = local.skillset_name
    aisearch_name     = azurerm_search_service.example.name
    aoai_endpoint_url = azurerm_cognitive_account.openai.endpoint
    function_endpoint = "https://${azurerm_linux_function_app.example.default_hostname}/api/AnalyzeDocument?code=${data.azurerm_function_app_host_keys.example.default_function_key}"
  }
}
resource "null_resource" "create_skillset" {
  triggers = {
    always_run = timestamp()
    //file_changed = md5(data.template_file.index.rendered)
  }
  provisioner "local-exec" {
    command = <<-EOT
      curl -v -X PUT \
      -H "Content-Type: application/json" \
      -H "api-key: ${nonsensitive(azurerm_search_service.example.primary_key)}" \
      -d '${data.template_file.skillset.rendered}' \
      "https://${azurerm_search_service.example.name}.search.windows.net/skillsets/${local.skillset_name}?api-version=2024-07-01"
    EOT
  }
}

// Update datasource by using null_resource
data "template_file" "datasource" {
  template = file("${path.module}/aisearch/datasource.json")
  vars = {
    container_name              = azurerm_storage_container.data.name
    storage_account_resource_id = azurerm_storage_account.data.id
  }
}
resource "null_resource" "create_datasource" {
  triggers = {
    always_run = timestamp()
    //file_changed = md5(data.template_file.index.rendered)
  }
  provisioner "local-exec" {
    command = <<-EOT
      curl -v -X PUT \
      -H "Content-Type: application/json" \
      -H "api-key: ${nonsensitive(azurerm_search_service.example.primary_key)}" \
      -d '${data.template_file.datasource.rendered}' \
      "https://${azurerm_search_service.example.name}.search.windows.net/datasources/${local.datasource_name}?api-version=2024-07-01"
    EOT
  }
}

// Update indexer by using null_resource
data "template_file" "indexer" {
  template = file("${path.module}/aisearch/indexer.json")
  vars = {
    datasource_name = local.datasource_name
    skillset_name   = local.skillset_name
    index_name      = local.index_name
  }
}

resource "null_resource" "name" {
  depends_on = [
    null_resource.create_datasource,
    null_resource.create_skillset,
    null_resource.create_index
  ]
  triggers = {
    always_run = timestamp()
    //file_changed = md5(data.template_file.indexer.rendered)
  }
  provisioner "local-exec" {
    command = <<-EOT
        curl -v -X PUT \
        -H "Content-Type: application/json" \
        -H "api-key: ${nonsensitive(azurerm_search_service.example.primary_key)}" \
        -d '${data.template_file.indexer.rendered}' \
        "https://${azurerm_search_service.example.name}.search.windows.net/indexers/${local.indexer_name}?api-version=2024-07-01"
    EOT
  }

}

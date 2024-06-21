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

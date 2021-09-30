# これは何？

APIM を ゾーン冗長 + 内部ネットワークに展開する Terraform + ARM テンプレートの一式です。

Terraform の AzureRM プロバイダー 2.76.0 では内部ネットワークかつAZに対応する APIM を展開する方法はサポートされていないため、ARM テンプレートを使用します。

想定として、予め VNet や NSG が展開されており、展開されているリソースを使って APIM を展開します。

予め展開が必要なリソースを展開する Terraform は `1_deploy-vnet` です。この Terraform を使用しなくても、手動で展開しても問題ありません。
APIM は `2_deploy-apim` で展開します。

# 作業手順

## 0. 変数の変更
`terraform.tfvars` を環境に合わせて編集します。

## 1. APIM を展開するために必要なリソースを展開する

以下を展開します。
- VNet
- NSG
- Public IP

```sh
cd 1_deploy-vnet
terraform plan -out tfplan -var-file ../terraform.tfvars
```
## 2. APIM を展開する

```sh
cd 2_deploy-vnet
terraform plan -out tfplan -var-file ../terraform.tfvars
```

こちらの UI 定義を使用して展開することもできます。

createUiDefnition.json

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FtsubasaxZZZ%2Fterraform-azure%2Fmain%2Fapim-to-internal-withAZ%2F2_deploy-apim%2Fazuredeploy.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FtsubasaxZZZ%2Fterraform-azure%2Fmain%2Fapim-to-internal-withAZ%2F2_deploy-apim%2FcreateUiDefinition.json)


uiForm.json

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FtsubasaxZZZ%2Fterraform-azure%2Fmain%2Fapim-to-internal-withAZ%2F2_deploy-apim%2Fazuredeploy.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FtsubasaxZZZ%2Fterraform-azure%2Fmain%2Fapim-to-internal-withAZ%2F2_deploy-apim%2Fuiform.json)

# 関連 Issue
- https://github.com/hashicorp/terraform-provider-azurerm/pull/12566
- https://github.com/hashicorp/terraform-provider-azurerm/issues/12021
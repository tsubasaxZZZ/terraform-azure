# これは何か

AI 関連のリソースを展開する Terraform です。
![alt text](image.png)

- Terraform では、リソースの一式の展開とManaged IDによるRBACの割り当てをします。
    - 各リソースのManaged IDを有効にします
    - アクセス先にアクセス元のManaged IDを割り当てます
    - ネットワークを特定のネットワークからのアクセスのみとし、"信頼された Azure サービスにアクセスを許可" を有効にします
- Azure Functions のアプリケーションの展開と、AI Search のインデックスやスキルセットはリソース展開後に手動で設定する必要があります。

## Azure Functions のアプリ
AI Search から呼び出される Azure Functions のアプリケーションが含まれています。

`AnalyzeDocument` ディレクトリ の `__init__.py` の `endpoint` には、Document Intelligence のエンドポイントを指定してください。

### アプリケーションの展開

```bash
az login --tenant microsoft.onmicrosoft.com --use-device-code
func azure functionapp publish func-j8o6ch
```

## AI Search の設定
AI Search のインデックス、インデクサー、スキルセットの JSON が含まれています。

## トラブルシューティング

### Cognitive Service Account が論理削除され再作成できない

```
│ Error: creating Account (Subscription: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
│ Resource Group Name: "rg-openai-private-20240618"
│ Account Name: "di-j8o6ch"): unexpected status 409 (409 Conflict) with error: CustomDomainInUse: Please pick a different name. The subdomain name 'dij8o6ch' is not available as it's already used by a resource. If the resource using the name was deleted in the last 48 hours, you may need to purge the deleted resource. Learn more at "https://go.microsoft.com/fwlink/?linkid=2215493"
│
│   with azurerm_cognitive_account.documentinteligence,
│   on ai.tf line 3, in resource "azurerm_cognitive_account" "documentinteligence":
│    3: resource "azurerm_cognitive_account" "documentinteligence" {
│                                                                   
```

以下のコマンドでリソースを削除します。
```bash
 az cognitiveservices account purge --resource-group rg-openai-private-20240618 --name di-j8o6ch -l japaneast
```

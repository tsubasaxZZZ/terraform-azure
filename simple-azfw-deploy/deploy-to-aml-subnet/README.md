# 既存のサブネットに Azure Firewall を展開する

## 追加で必要な作業

- 展開先のサブネットを作成する
- Azure Firewall を展開後に UDR を設定する


## 展開されるリソース

- Azure Firewall Premium
- Azure Firewall ポリシー
  - Azure Machine Learning に必要なルールを設定済み
- Public IP Address

## 展開方法

### 設定ファイル

`terraform.tfvars` を作成し設定を記述する

```
# Azure Firewall を展開する先のリソース グループ情報
rg = {
  location = "japaneast"
  name = "rg-simple-azfw"
}

# リソースを識別するための任意の文字列
id = "tsunomur"

# 展開先のサブネットのリソース ID
subnet_id = "/subscriptions/<Subscription ID>/resourceGroups/rg-simple-azfw/providers/Microsoft.Network/virtualNetworks/vnet-azfw/subnets/AzureFirewallSubnet"

# Azure Firewall への送信元の IP アドレス空間
source_ip_range = "172.17.0.0/24"
```

### 展開

```:bash
az login
terraform init
terraform plan -out tfplan
terraform apply "tfplan"
```

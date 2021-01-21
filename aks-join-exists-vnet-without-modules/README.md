# 既存の仮想ネットワークへ AKS を展開する

## 事前準備

以下を予め展開します。

### Azure 環境

- Azure Container Registry
- Log Analytics ワークスペース
- 仮想ネットワーク

### ツール

- terraform
    - https://www.terraform.io/downloads.html

## 展開

### 1. 設定ファイルの変更

変更が必要な箇所について `terraform.tfvars` を編集します。

### 2. Azure CLI のログイン

```
az login (Cloud Shell の場合は不要)
az account set --subscription <サブスクリプション ID>
```

### 2. 展開

以下を実行します。

```
terraform plan -out tfplan
terraform apply tfplan
```

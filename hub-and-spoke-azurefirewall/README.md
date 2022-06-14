# Azure Firewall testbed

## これは何か

Azure Firewall と 仮想ネットワーク のピアリングを使用してハブスポークの構成やルーティングを確認するためのテストベッドです。

## できるもの

- ハブアンドスポークの環境が2つ作成されます
  - ハブ x 2、スポーク x 4
- 2つのハブ間はピアリングで接続されます
- ハブには Azure Firewall が展開されます
- それぞれスポークは UDR で Azure Firewall にルートされます
- ハブは UDR で相互にスポークのルートを対向の Azure Firewall にルートします
- スポークに 1 つずつ Linux VM が展開されます
  - 各スポーク間の VM は相互に通信できます
  - VM は 2:00(JST) に自動シャットダウンします
- それぞれのハブに Bastion が展開されます
- Azure Firewall の診断設定で Log Analytics が設定されます

## デプロイ方法

### 1. 事前準備

Terraform で Azure のリソースを展開するための認証情報を取得します。以下はサービス プリンシパルを使う方法です。

```sh
az ad sp create-for-rbac --name terraform-deploy --role Contributor

export ARM_CLIENT_ID="<Client ID>"
export ARM_CLIENT_SECRET="<Client Secret>"
export ARM_SUBSCRIPTION_ID="<Subscription ID>"
export ARM_TENANT_ID="<Tenant ID>"
```

### 2. 展開

- hub1 を展開した後に hub2 を展開します
- hub1 だけの展開でも問題ありません
- hub2 の展開によって、hub1 とのピアリングや UDR のルートが作成されます

#### hub1 の展開

```sh
cd hub-spoke1
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

#### hub2 の展開

```sh
cd hub-spoke2
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

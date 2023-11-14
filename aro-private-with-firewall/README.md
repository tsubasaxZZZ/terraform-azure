# これは何か

Azure Redhat OpenShift を 展開する Terraform です。

- 仮想ネットワーク内に ARO を展開します
- API Server と Ingress のエンドポイントを Private にできます(既定は Private です)


## 事前準備

### サービスプリンシパルを作る

```sh
az ad sp create-for-rbac --name <任意の名前> > principal.json
# aad_sp_client_id の値
aroClusterServicePrincipalClientId=$(jq -r '.appId' principal.json)
# aad_sp_client_secret の値
aroClusterServicePrincipalClientSecret=$(jq -r '.password' principal.json)
# aad_sp_object_id の値
aroClusterServicePrincipalObjectId=$(az ad sp show --id $aroClusterServicePrincipalClientId | jq -r '.id')
# rp_aad_sp_object_id の値
az ad sp list --display-name "Azure Red Hat OpenShift RP" --query [0].id -o tsv
```

これらの結果を `terraform.tfvars` に記載します。

terraform.tfvars のサンプル:

```hcl
rg = {
  name     = "rg-aro-private-eastus",
  location = "eastus",
}

aro_cluster = {
  aad_sp_client_id      = "6e585ffb-eaae-49f6-b93a-6bd8f8dd3459"
  aad_sp_object_id      = "bba3c208-1f2c-4a4d-a921-d803efecafe9"
  rp_aad_sp_object_id   = "50c17c64-bc11-4fdd-a339-0ecd396bf221"
  domain                = "tsunomur1"
}
aro_aad_sp_client_secret = "<secret>"
``

## ドキュメント

[API リファレンス - Open Shift Clusters - Create Or Update](https://learn.microsoft.com/en-us/rest/api/openshift/open-shift-clusters/create-or-update?view=rest-openshift-2023-09-04&tabs=HTTP)
[Deploy an Azure Red Hat OpenShift cluster with Terraform and AzAPI Provider](https://learn.microsoft.com/en-us/samples/azure-samples/aro-azapi-terraform/aro-azapi-terraform/)

# これは何か

Azure Redhat OpenShift を 展開する Terraform です。

- 仮想ネットワーク内に ARO を展開します
- API Server と Ingress のエンドポイントを Private にできます(既定は Private です)


## 事前準備

### サービスプリンシパルを作る

```sh
az ad sp create-for-rbac -o json --name <任意の名前> > principal.json
# aad_sp_client_id の値
aroClusterServicePrincipalClientId=$(jq -r '.appId' principal.json)
# aad_sp_client_secret の値
aroClusterServicePrincipalClientSecret=$(jq -r '.password' principal.json)
# aad_sp_object_id の値
aroClusterServicePrincipalObjectId=$(az ad sp show --id $aroClusterServicePrincipalClientId -o json | jq -r '.id')
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
```

## 監視の有効化

ARO の監視には Azure Arc を利用する方法と利用しない方法があります。

### Option 1 : Azure Arc を利用する場合

#### 1. Azure Arc への接続
始めに、Azur Arc に接続します。

- [クイックスタート: 既存の Kubernetes クラスターを Azure Arc に接続する](https://learn.microsoft.com/ja-jp/azure/azure-arc/kubernetes/network-requirements?tabs=azure-cloud)
- ネットワーク要件
  - [Azure Arc 対応 Kubernetes ネットワークの要件](https://learn.microsoft.com/ja-jp/azure/azure-arc/kubernetes/network-requirements?tabs=azure-cloud)


```sh
az connectedk8s connect --name aro-ld5fzm7n --resource-group rg-aro-private-eastus
This operation might take a while...

The required pre-checks for onboarding have succeeded.

Azure resource provisioning has begun.
Azure resource provisioning has finished.
Starting to install Azure arc agents on the Kubernetes cluster.
AgentPublicKeyCertificate

ConnectivityStatus    Distribution    Infrastructure    Location    Name          ProvisioningState    ResourceGroup
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  --------------------  --------------  ----------------  ----------  ------------  -------------------  ---------------------
Connecting            openshift       azure             eastus      aro-ld5fzm7n  Succeeded            rg-aro-private-eastus
```

#### 2. Azure Arc の拡張のインストール

- ドキュメント
  - [Azure Arc 対応 Kubernetes クラスター用の Azure Monitor Container Insights](https://learn.microsoft.com/ja-jp/azure/azure-monitor/containers/container-insights-enable-arc-enabled-clusters?tabs=create-cli%2Cverify-portal%2Cmigrate-cli)
  - [az k8s-extension create で指定できるオプション](https://github.com/microsoft/Docker-Provider/blob/ci_prod/charts/azuremonitor-containers/values.yaml)
- ARO は Managed ID 認証が出来ないため、`aadAuth` を false にする
- `logAnalyticsWorkspaceResourceID` で Log Analytics ワークスペースの リソース ID を指定する
  - amalogs.secret.wsid と amalogs.secret.key を指定しても無視される
  - `az k8s-extension` コマンド側でキーが取得され Secret オブジェクトが作成されている
  - Secret の確認: `oc get secret -n kube-system ama-logs-secret -o yaml`

コマンドの実行結果:
```sh
RESOURCEGROUP="rg-aro-private-eastus"
CLUSTER="aro-ld5fzm7n"
WS_RID=<Log Analytics ワークスペースの リソース ID(Workspace IDではない)>
az k8s-extension create --name azuremonitor-containers --cluster-name $CLUSTER --resource-group $RESOURCEGROUP --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --configuration-settings amalogs.useAADAuth=false logAnalyticsWorkspaceResourceID=<Log Analytics ワークスペースの リソース ID>

# 実行結果
AutoUpgradeMinorVersion    CurrentVersion    ExtensionType                      IsSystemExtension    Name                     ProvisioningState    ReleaseTrain    ResourceGroup
-------------------------  ----------------  ---------------------------------  -------------------  -----------------------  -------------------  --------------  ---------------------
True                       3.1.14            microsoft.azuremonitor.containers  False                azuremonitor-containers  Succeeded            Stable          rg-aro-private-eastus
```

参考: `az k8s-extension create` のデバッグ実行:
```
cli.azure.cli.core.sdk.policies: Request URL: 'https://management.azure.com/subscriptions/xxxxxxxxxxx/resourceGroups/rg-aro-private-eastus/providers/Microsoft.Kubernetes/connectedClusters/aro-ld5fzm7n/providers/Microsoft.KubernetesConfiguration/extensions/azuremonitor-containers?api-version=2023-05-01'
cli.azure.cli.core.sdk.policies: Request method: 'PUT'
cli.azure.cli.core.sdk.policies: Request headers:
cli.azure.cli.core.sdk.policies:     'Content-Type': 'application/json'
cli.azure.cli.core.sdk.policies:     'Content-Length': '821'
cli.azure.cli.core.sdk.policies:     'Accept': 'application/json'
cli.azure.cli.core.sdk.policies:     'x-ms-client-request-id': 'e7991203-8320-11ee-9e97-00224833d212'
cli.azure.cli.core.sdk.policies:     'CommandName': 'k8s-extension create'
cli.azure.cli.core.sdk.policies:     'ParameterSetName': '--name --cluster-name --resource-group --cluster-type --extension-type --configuration-settings --debug'
cli.azure.cli.core.sdk.policies:     'User-Agent': 'AZURECLI/2.54.0 (MSI) azsdk-python-azure-mgmt-kubernetesconfiguration/0.1.0 Python/3.11.5 (Windows-10-10.0.20348-SP0)'
cli.azure.cli.core.sdk.policies:     'Authorization': '*****'
cli.azure.cli.core.sdk.policies: Request body:
cli.azure.cli.core.sdk.policies: {"identity": {"type": "SystemAssigned"}, "properties": {"extensionType": "microsoft.azuremonitor.containers", "scope": {"cluster": {"releaseNamespace": "azuremonitor-containers"}}, "configurationSettings": {"amalogs.useAADAuth": "false", "logAnalyticsWorkspaceResourceID": "/subscriptions/xxxxxxxxxx/resourceGroups/rg-aro-private-eastus/providers/Microsoft.OperationalInsights/workspaces/la-ld5fzm7n"}, "configurationProtectedSettings": {"omsagent.secret.key": "Jrc0Zxxxx", "amalogs.secret.key": "Jrc0Zxxxx", "omsagent.secret.wsid": "d44ba5ca-7e2a-4ee7-9444-xxxxxx", "amalogs.secret.wsid": "d44ba5ca-7e2a-4ee7-9444-xxxxxx"}}}
```

#### オンボード時のトラブルシューティング

[Troubleshoot Guide for Azure Monitor for containers](https://github.com/microsoft/Docker-Provider/blob/ci_prod/scripts/troubleshoot/README.md#azure-arc-enabled-kubernetes-1)

### Option 2 : Azure Arc を利用しない場合

Log Analytics と Container Insights をインストールします。

- [Container insights を使用してハイブリッド Kubernetes クラスターを構成する](https://learn.microsoft.com/ja-jp/azure/azure-monitor/containers/container-insights-hybrid-setup)

コマンド例:
```
CLUSTER=aro-ld5fzm7n

oc login --token=<TOKEN> --server=https://api.ld5fzm7n.eastus.aroapp.io:6443
helm install myamaext --set amalogs.secret.wsid=<Log Analytics ワークスペースの ID> --set amalogs.secret.key=<Log Analytics ワークスペースの Key> --set amalogs.env.clusterName=$CLUSTER microsoft/azuremonitor-containers
```

## ドキュメント

[API リファレンス - Open Shift Clusters - Create Or Update](https://learn.microsoft.com/en-us/rest/api/openshift/open-shift-clusters/create-or-update?view=rest-openshift-2023-09-04&tabs=HTTP)
[Deploy an Azure Red Hat OpenShift cluster with Terraform and AzAPI Provider](https://learn.microsoft.com/en-us/samples/azure-samples/aro-azapi-terraform/aro-azapi-terraform/)

### Azure Monitor で取得できるログ

[リソースの種類別に整理された Azure Monitor ログ テーブルリファレンス](https://learn.microsoft.com/ja-jp/azure/azure-monitor/reference/tables/tables-resourcetype#azure-arc-enabled-kubernetes)
[Container insights の監視コストについて](https://learn.microsoft.com/ja-jp/azure/azure-monitor/containers/container-insights-cost#data-collected-from-kubernetes-clusters)

- ARO には AKS のように診断設定が無いのでホストの syslog 等一部のログは取得できない
  - [Container Insights を使用した Syslog 収集 (プレビュー)](https://learn.microsoft.com/ja-jp/azure/azure-monitor/containers/container-insights-syslog)
    - マネージド ID が必要だが ARO では Managed ID が利用できない

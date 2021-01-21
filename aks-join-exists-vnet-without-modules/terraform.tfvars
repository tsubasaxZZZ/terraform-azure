# リソース グループ名
resource_group_name = "rg-aksdemoforkip"
# 展開先のリージョン
location = "japaneast"
# AKS の名前
name = "aksdemo0121"
# サブネットの リソース ID
vnet_subnet_id = "/subscriptions/d0a3116c-66da-4e72-a8f4-16a69487758d/resourceGroups/rg-aksdemoforkip/providers/Microsoft.Network/virtualNetworks/rgaksdemoforkipvnet850/subnets/aks"
# ACR のリソース ID
container_registry_id = "/subscriptions/d0a3116c-66da-4e72-a8f4-16a69487758d/resourceGroups/rg-aksdemoforkip/providers/Microsoft.ContainerRegistry/registries/acraksdemoforkip"
# Log Analytics ワークスペースのリソース ID
log_analytics_workspace_id = "/subscriptions/d0a3116c-66da-4e72-a8f4-16a69487758d/resourcegroups/rg-aksdemoforkip/providers/microsoft.operationalinsights/workspaces/la-aksdemoforkip"
# k8s のバージョン
kubernetes_version = "1.18.14"
# SKU(Paid: Uptime SLA, Free: Uptime SLA ではない)
sla_sku = "Paid"
# プライベートクラスタ
private_cluster = false
# デフォルトノードプールの設定
default_node_pool = {
    # ノードプールの名前
    name = "agentpool"
    # ノード数
    node_count = 1
    # VM サイズ
    vm_size = "Standard_DS2_v2"
    # ゾーン(ゾーンがないリージョンの場合は空[]にする)
    zones = [1,2,3]
    # ラベル
    labels = {}
    # テイント
    taints = []
    # オートスケーラーの設定
    cluster_auto_scaling = false
    cluster_auto_scaling_max_count = null
    cluster_auto_scaling_min_count = null
}
# 追加のノードプール
additional_node_pools = {}
# アドオン
addons = {
    oms_agent = true
    azure_policy = false
    kubernetes_dashboard = false
}
# 許可された IP アドレス範囲
api_auth_ips = null
# AAD グループ(AAD統合用)
aad_group_name = null
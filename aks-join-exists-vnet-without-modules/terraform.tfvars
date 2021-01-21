resource_group_name = "rg-aksdemoforkip"
location = "japaneast"
name = "aksdemo0121"
vnet_subnet_id = "/subscriptions/d0a3116c-66da-4e72-a8f4-16a69487758d/resourceGroups/rg-aksdemoforkip/providers/Microsoft.Network/virtualNetworks/rgaksdemoforkipvnet850/subnets/aks"
container_registry_id = "/subscriptions/d0a3116c-66da-4e72-a8f4-16a69487758d/resourceGroups/rg-aksdemoforkip/providers/Microsoft.ContainerRegistry/registries/acraksdemoforkip"
log_analytics_workspace_id = "/subscriptions/d0a3116c-66da-4e72-a8f4-16a69487758d/resourcegroups/rg-aksdemoforkip/providers/microsoft.operationalinsights/workspaces/la-aksdemoforkip"
kubernetes_version = "1.18.14"
sla_sku = "Paid"
private_cluster = false
default_node_pool = {
    name = "agentpool"
    node_count = 1
    vm_size = "Standard_DS2_v2"
    zones = [1,2,3]
    labels = {}
    taints = []
    cluster_auto_scaling = false
    cluster_auto_scaling_max_count = null
    cluster_auto_scaling_min_count = null
}
additional_node_pools = {}
addons = {
    oms_agent = true
    azure_policy = false
    kubernetes_dashboard = false
}
api_auth_ips = null
aad_group_name = null
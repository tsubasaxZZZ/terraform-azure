terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.0"
    }
  }
}

data "azurerm_client_config" "current" {
}

resource "azurerm_role_assignment" "aro_cluster_service_principal_network_contributor" {
  scope                = var.virtual_network_id
  role_definition_name = "Contributor"
  principal_id         = var.aro_cluster_aad_sp_object_id
}

resource "azurerm_role_assignment" "aro_resource_provider_service_principal_network_contributor" {
  scope                            = var.virtual_network_id
  role_definition_name             = "Contributor"
  principal_id                     = var.aro_rp_aad_sp_object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "aro_oid_uam" {
  scope                = data.azurerm_resource_group.resource_group.id
  role_definition_name = "User Access Administrator"
  principal_id         = var.aro_cluster_aad_sp_object_id
}

resource "azurerm_role_assignment" "aro_oid_contributor" {
  scope                = data.azurerm_resource_group.resource_group.id
  role_definition_name = "Contributor"
  principal_id         = var.aro_cluster_aad_sp_object_id
}


locals {
  resource_group_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/aro-${var.domain}"
  master_subnet_id  = "${var.virtual_network_id}/subnets/${var.master_subnet_name}"
  worker_subnet_id  = "${var.virtual_network_id}/subnets/${var.worker_subnet_name}"
}
data "azurerm_resource_group" "resource_group" {
  name = var.resource_group_name
}

resource "azapi_resource" "aro_cluster" {
  depends_on = [
    azurerm_role_assignment.aro_oid_uam,
    azurerm_role_assignment.aro_oid_contributor,
  ]

  name      = var.cluster_name
  location  = var.location
  parent_id = data.azurerm_resource_group.resource_group.id
  type      = "Microsoft.RedHatOpenShift/openShiftClusters@2023-09-04"
  tags      = var.tags

  body = jsonencode({
    properties = {
      clusterProfile = {
        domain               = var.domain
        fipsValidatedModules = var.fips_validated_modules
        resourceGroupId      = local.resource_group_id
        pullSecret           = var.pull_secret
      }
      networkProfile = {
        podCidr      = var.pod_cidr
        serviceCidr  = var.service_cidr
        outboundType = var.outbound_type
      }
      servicePrincipalProfile = {
        clientId     = var.aro_cluster_aad_sp_client_id
        clientSecret = var.aro_cluster_aad_sp_client_secret
      }
      masterProfile = {
        vmSize           = var.master_node_vm_size
        subnetId         = local.master_subnet_id
        encryptionAtHost = var.master_encryption_at_host
      }
      workerProfiles = [
        {
          name             = var.worker_profile_name
          vmSize           = var.worker_node_vm_size
          diskSizeGB       = var.worker_node_vm_disk_size
          subnetId         = local.worker_subnet_id
          count            = var.worker_node_count
          encryptionAtHost = var.worker_encryption_at_host
        }
      ]
      apiserverProfile = {
        visibility = var.api_server_visibility
      }
      ingressProfiles = [
        {
          name       = var.ingress_profile_name
          visibility = var.ingress_visibility
        }
      ]
    }
  })

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
  timeouts {
    create = "60m"
    delete = "60m"
  }
}

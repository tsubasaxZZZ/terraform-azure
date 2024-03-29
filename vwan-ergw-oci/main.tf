terraform {
  required_version = "~> 1.7"
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

provider "azurerm" {
  features {}
}
provider "oci" {
  tenancy_ocid     = var.oci_configuration.tenancy_ocid
  user_ocid        = var.oci_configuration.user_ocid
  private_key_path = var.oci_configuration.private_key_path
  fingerprint      = var.oci_configuration.fingerprint
  region           = var.oci_configuration.region
}

module "oci" {
  source                = "./oci"
  azure_base_cidr_block = var.base_cidr_block
  oci_configuration     = var.oci_configuration
  oci_base_cidr_block   = var.oci_base_cidr_block
  ssh_authorized_keys   = var.ssh_authorized_keys
}

module "azure" {
  source              = "./azure"
  er_circuit_location = var.er_circuit_location
  base_cidr_block     = var.base_cidr_block
  deploy_vwan         = var.deploy_vwan
  rg                  = var.rg
}

// -------------------------
// Create Virtual Circuit
// -------------------------

resource "oci_core_virtual_circuit" "example" {
  #Required
  compartment_id = var.oci_configuration.compartment_id
  type           = "PRIVATE"

  #Optional
  bandwidth_shape_name = "1 Gbps"
  cross_connect_mappings {
    customer_bgp_peering_ip = "10.255.255.2/30"
    oracle_bgp_peering_ip   = "10.255.255.1/30"
  }
  cross_connect_mappings {
    customer_bgp_peering_ip = "10.255.255.6/30"
    oracle_bgp_peering_ip   = "10.255.255.5/30"
  }
  gateway_id                = module.oci.drg_id
  provider_service_id       = "ocid1.providerservice.oc1.ap-tokyo-1.aaaaaaaaea5dqs2zg7ecvenqai6yhfm4idgseycgkgtqjkbbcvul2tnsprwa"
  provider_service_key_name = module.azure.expressroute_circuit_servicekey
}


resource "azurerm_virtual_network_gateway_connection" "example" {
  name                = "er-to-oci"
  location            = var.rg.location
  resource_group_name = var.rg.name

  type                       = "ExpressRoute"
  virtual_network_gateway_id = module.azure.virtual_network_gateway_id
  express_route_circuit_id   = module.azure.expressroute_circuit_id
}

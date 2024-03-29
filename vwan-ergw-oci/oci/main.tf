terraform {
  required_version = "~> 1.7"
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.oci_configuration.tenancy_ocid
  user_ocid        = var.oci_configuration.user_ocid
  private_key_path = var.oci_configuration.private_key_path
  fingerprint      = var.oci_configuration.fingerprint
  region           = var.oci_configuration.region
}

locals {
  compartment_id = var.oci_configuration.compartment_id
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = local.compartment_id
}

// -----------------------
// Create OCI VCN
// -----------------------
resource "oci_core_vcn" "example" {
  cidr_block     = var.oci_base_cidr_block
  compartment_id = local.compartment_id
  display_name   = "vcn-for-azure"
  dns_label      = "dnsforvnc"
}

resource "oci_core_subnet" "public_subnet" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.example.id
  cidr_block                 = cidrsubnet(oci_core_vcn.example.cidr_block, 8, 1)
  display_name               = "public_subnet"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.example.id
  security_list_ids          = [oci_core_security_list.example.id]
  dhcp_options_id            = oci_core_vcn.example.default_dhcp_options_id
  prohibit_public_ip_on_vnic = false
}

resource "oci_core_subnet" "private_subnet" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.example.id
  cidr_block                 = cidrsubnet(oci_core_vcn.example.cidr_block, 8, 2)
  display_name               = "private_subnet"
  dns_label                  = "private"
  route_table_id             = oci_core_route_table.example.id
  security_list_ids          = [oci_core_security_list.example.id]
  dhcp_options_id            = oci_core_vcn.example.default_dhcp_options_id
  prohibit_public_ip_on_vnic = true
}

resource "oci_core_route_table" "example" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.example.id
  display_name   = "example_rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.example.id
  }

  route_rules {
    destination       = var.azure_base_cidr_block
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_drg.example.id
  }
  
}

resource "oci_core_security_list" "example" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.example.id
  display_name   = "example_sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_internet_gateway" "example" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.example.id
  display_name   = "example_igw"
  enabled        = true
}

// -------------------------
// Create DRG
// -------------------------
resource "oci_core_drg" "example" {
  compartment_id = local.compartment_id
  display_name   = "example_drg"
}
resource "oci_core_drg_attachment" "example" {
  drg_id        = oci_core_drg.example.id
  vcn_id        = oci_core_vcn.example.id
  display_name  = "example_drg_attachment"
}

// -------------------------
// Create Instance
// -------------------------
resource "oci_core_instance" "example" {
  # Required
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = local.compartment_id
  shape               = "VM.Standard.E2.1.Micro"
  source_details {
    source_id   = "ocid1.image.oc1.ap-tokyo-1.aaaaaaaaudam2npa5hvdwtxk6zditcmqyb6audyj6bpa2dnum6s4bp5jmpca"
    source_type = "image"
  }

  # Optional
  display_name = "linuxvm"
  create_vnic_details {
    assign_public_ip = true
    subnet_id        = oci_core_subnet.public_subnet.id
  }
  metadata = {
    ssh_authorized_keys = file(var.ssh_authorized_keys)
  }
  preserve_boot_volume = false
}

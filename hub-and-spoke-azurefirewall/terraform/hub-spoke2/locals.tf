locals {
    hub_vnet = {
        base_cidr_block = "10.1.0.0/16"
    }
    spoke_vnet1 = {
        base_cidr_block = "10.101.0.0/16"
    }
    spoke_vnet2 = {
        base_cidr_block = "10.201.0.0/16"
    }
}

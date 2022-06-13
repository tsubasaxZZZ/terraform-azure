locals {
    hub_vnet = {
        base_cidr_block = "10.0.0.0/16"
    }
    spoke_vnet1 = {
        base_cidr_block = "10.100.0.0/16"
    }
    spoke_vnet2 = {
        base_cidr_block = "10.200.0.0/16"
    }
}

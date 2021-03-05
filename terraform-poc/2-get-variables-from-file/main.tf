variable "vm_sku" {
  default = "Standard_D2_v2"
}

locals {
  enableAcceleratedNetworking = jsondecode(data.template_file.example.rendered)
}

data "template_file" "example" {
  template = file("${path.module}/AcceleratedNetworkingEnabledVM.json")
}

output "condition" {
  value = contains(local.enableAcceleratedNetworking, var.vm_sku)
}

output "variables_from_file" {
  value = local.enableAcceleratedNetworking
}

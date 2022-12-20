rg = {
  name     = "rg-azfw-vpngw-1220d"
  location = "japaneast"
}

onprem_network = {
  bgp_peering_address = "192.168.1.1"
  gateway_address     = "150.31.11.227"
  shared_key          = "share"
  bgp_asn             = 65050
}
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCythmaDMBX8Eatx5mqlF0JJ1pNGXePUreGuuAe3yQb+bWbxQJRFuMpYBpKZjZesIUfA86qwaK+c+mD2Sw5GKKIOca6Jj228gYBEBaEzFYZy5Pc3IyZL/3q41OS4kQD27+xIneDGmUnZBXCiuqsXdrw8cSMY6/Cj1tn6UsB4eN1ZZ3AJsTjoZwJSqSmApvavlYl+nPaHlN3fZFF0vwomeLKF3KWahcgIhqxpK5hnjDHWHb0S3bcBwO7NeBIeZqdDAP3Zc17jbgBWKdKy73AZrSRKJh/f8Hvx6qBTRD/IomD+jYOLBPb/gDUYACOyKxB9szwmG/8wQY1dzZNGURCpL3v"

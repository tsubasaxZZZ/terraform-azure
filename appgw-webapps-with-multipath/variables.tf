variable "rg" {
  type = object({
    name     = string
    location = string
  })
  default = {
    name     = "rg-webapp-appgw"
    location = "japaneast"
  }
}

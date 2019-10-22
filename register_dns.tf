# resource "azurerm_resource_group" "dns_rg" {
#  name     = "RH-FORUM-2019"
#  location = "francecentral"
# }

variable "dns_rg" {
  default = "cacib-poc-watson"
}

variable "clustership_zone" {
  default = "cacib.azure.clustership.com"
}

# resource "azurerm_dns_zone" "clustership_zone" {
#   name                = "cacib.azure.clustership.com"
#   resource_group_name = var.dns_rg
# }

# resource "azurerm_dns_a_record" "sat_record" {
#   name                = "cacib-sat-bastion"
#   zone_name           = var.clustership_zone
#   resource_group_name = var.dns_rg
#   ttl                 = 300
#   records             = ["${azurerm_public_ip.myterraformpublicip.ip_address}"]
# }

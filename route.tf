resource "azurerm_route_table" "cacibprivateroutetable" {
  name                = "cacib-private-route-table"
  location            = var.azure_region
  resource_group_name = "${azurerm_resource_group.main.name}"
}

resource "azurerm_route" "cacibprivatevnetroute" {
  name                = "cacib-private-net-route"
  resource_group_name = "${azurerm_resource_group.main.name}"
  route_table_name    = "${azurerm_route_table.cacibprivateroutetable.name}"
  address_prefix      = "10.5.2.0/24"
  next_hop_type       = "vnetlocal"
}

resource "azurerm_route" "cacib_private_vnet_gw_route" {
  name                = "cacib-private-vnet-gw-route"
  resource_group_name = "${azurerm_resource_group.main.name}"
  route_table_name    = "${azurerm_route_table.cacibprivateroutetable.name}"
  address_prefix      = "10.5.2.1/32"
  next_hop_type       = "none"
}

#resource "azurerm_route" "cacib_private_vnet_dns_route" {
#  name                = "cacib-private-vnet-dns-route"
#  resource_group_name = "${azurerm_resource_group.main.name}"
#  route_table_name    = "${azurerm_route_table.cacibprivateroutetable.name}"
#  address_prefix      = "168.63.129.16/32"
#  next_hop_type       = "none"
#}

#resource "azurerm_route" "cacib_private_vnet_metadata_route" {
#  name                = "cacib-private-vnet-metadata-route"
#  resource_group_name = "${azurerm_resource_group.main.name}"
#  route_table_name    = "${azurerm_route_table.cacibprivateroutetable.name}"
#  address_prefix      = "168.63.129.254/32"
#  next_hop_type       = "none"
#}

resource "azurerm_route" "cacibprivatevnetdefaultroute" {
  name                = "cacib-private-net-default-route"
  resource_group_name = "${azurerm_resource_group.main.name}"
  route_table_name    = "${azurerm_route_table.cacibprivateroutetable.name}"
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "none"
}

resource "azurerm_subnet_route_table_association" "cacib_private_subnet_route_table" {
  subnet_id      = "${azurerm_subnet.myterraformprivatesubnet.id}"
  route_table_id = "${azurerm_route_table.cacibprivateroutetable.id}"
}

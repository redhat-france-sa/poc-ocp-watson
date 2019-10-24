#
# Must be dynamic
#
variable "cluster_id" {
  default = "cacib-ocp-disconnected-install"
}

variable "ssh_key_private" {
  default = "~/.ssh/terraform_id_rsa"
}

locals {
  tags = merge(
    {
      "kubernetes.io_cluster.${var.cluster_id}" = "owned"
    },
    var.azure_extra_tags,
  )
}


variable "azure_bastion_vm_size" {
  default = "Standard_A2m_v2"
}

variable "azure_master_vm_size" {
  default = "Standard_DS3_v2"
}

variable "azure_node_vm_size" {
  default = "Standard_DS3_v2"
}

module "bootstrap" {
  source              = "./bootstrap"
  resource_group_name = azurerm_resource_group.main.name
  region              = var.azure_region
  vm_size             = var.azure_bootstrap_vm_type
#  vm_image            = azurerm_image.cluster.id
#  identity            = azurerm_user_assigned_identity.main.id
#  subnet_id           = module.vnet.master_subnet_id
  public_subnet_id           = azurerm_subnet.cacib_ocp_public_subnet.id
  private_subnet_id          = azurerm_subnet.myterraformprivatesubnet.id
  public_ip_address_id       = azurerm_public_ip.myterraformpublicip.id
  public_ip_address_name     = azurerm_public_ip.myterraformpublicip.name
  tags                = local.tags
#  storage_account     = azurerm_storage_account.cluster
#  nsg_name            = module.vnet.master_nsg_name
  storage_account     = azurerm_storage_account.mystorageaccount
  nsg_name            = azurerm_network_security_group.myterraformnsg.id

  ssh_key_private     = var.ssh_key_private
  admin_username      = "ocpadmin"
}

module "bastion" {
  source              = "./bastion"
  resource_group_name = azurerm_resource_group.main.name
  region              = var.azure_region
  vm_size             = var.azure_bastion_vm_size
  public_subnet_id           = azurerm_subnet.cacib_ocp_public_subnet.id
  private_subnet_id          = azurerm_subnet.myterraformprivatesubnet.id
  tags                = local.tags
  storage_account     = azurerm_storage_account.mystorageaccount
  nsg_name            = azurerm_network_security_group.myterraformnsg.id

  ssh_key_private     = var.ssh_key_private
  admin_username      = "ocpadmin"
}

module "master" {
  source              = "./master"
  resource_group_name = azurerm_resource_group.main.name
  region              = var.azure_region
  vm_size             = var.azure_master_vm_size
  public_subnet_id    = azurerm_subnet.cacib_ocp_public_subnet.id
  private_subnet_id   = azurerm_subnet.myterraformprivatesubnet.id
  tags                = local.tags
  storage_account     = azurerm_storage_account.mystorageaccount
  nsg_name            = azurerm_network_security_group.myterraformnsg.id
  instance_count      = var.master_count
  
  #
  # TODO: Refactor this
  #
  address_space       = var.address_space

  ssh_key_private     = var.ssh_key_private
  admin_username      = "ocpadmin"
}

module "node" {
  source              = "./node"
  resource_group_name = azurerm_resource_group.main.name
  region              = var.azure_region
  vm_size             = var.azure_node_vm_size
  public_subnet_id    = azurerm_subnet.cacib_ocp_public_subnet.id
  private_subnet_id   = azurerm_subnet.myterraformprivatesubnet.id
  tags                = local.tags
  storage_account     = azurerm_storage_account.mystorageaccount
  nsg_name            = azurerm_network_security_group.myterraformnsg.id
  instance_count      = var.node_count
  
  #
  # TODO: Refactor this
  #
  address_space       = var.address_space

  ssh_key_private     = var.ssh_key_private
  admin_username      = "ocpadmin"
}

# Create a resource group if it doesn’t exist
variable "address_space" {
  default = "10.5.0.0/16"
}


variable "admin_username" {
  default = "ocpadmin"
}


resource "null_resource" "reset_ip_addresses" {
  provisioner "local-exec" {
    command = "rm -f private-ips.txt"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "${var.cluster_id}-rg"
  location = var.azure_region
  tags     = local.tags
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "cacib-ocp-public-vnet"
    address_space       = [var.address_space]
    location            = var.azure_region
    resource_group_name = "${azurerm_resource_group.main.name}"

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

# Create primary subnet
resource "azurerm_subnet" "cacib_ocp_public_subnet" {
    name                 = "cacib-ocp-public-subnet"
    resource_group_name  = "${azurerm_resource_group.main.name}"
    virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
    address_prefix       = cidrsubnet(var.address_space, 8, 1)
}

# Create private subnet
resource "azurerm_subnet" "myterraformprivatesubnet" {
    name                 = "cacib-ocp-private-subnet"
    resource_group_name  = "${azurerm_resource_group.main.name}"
    virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
    route_table_id       = "${azurerm_route_table.cacibprivateroutetable.id}"
    address_prefix       = cidrsubnet(var.address_space, 8, 2)
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "cacib-sat-publicIP"
    location                     = var.azure_region
    resource_group_name          = "${azurerm_resource_group.main.name}"
    allocation_method            = "Dynamic"

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "cacib-ocp-public-sg"
    location            = var.azure_region
    resource_group_name = "${azurerm_resource_group.main.name}"
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTPS"
        priority                   = 1011
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTP"
        priority                   = 1021
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.main.name}"
    }
    
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.main.name}"
    location                    = var.azure_region
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}


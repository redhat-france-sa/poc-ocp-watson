# Create a resource group if it doesn’t exist
variable "location" {
  default = "francecentral"
}

variable "bastion_vm_size" {
  default = "Standard_A2m_v2"
}

variable "master_vm_size" {
  default = "Standard_DS3_v2"
}

resource "azurerm_resource_group" "myterraformgroup" {
    name     = "cacib-ocp-disconnected-rg"
    location = var.location

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "cacib-ocp-public-vnet"
    address_space       = ["10.5.0.0/16"]
    location            = var.location
    resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

# Create primary subnet
resource "azurerm_subnet" "cacib_ocp_public_subnet" {
    name                 = "cacib-ocp-public-subnet"
    resource_group_name  = "${azurerm_resource_group.myterraformgroup.name}"
    virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
    address_prefix       = "10.5.1.0/24"
}

# Create private subnet
resource "azurerm_subnet" "myterraformprivatesubnet" {
    name                 = "cacib-ocp-private-subnet"
    resource_group_name  = "${azurerm_resource_group.myterraformgroup.name}"
    virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
    route_table_id       = "${azurerm_route_table.cacibprivateroutetable.id}"
    address_prefix       = "10.5.2.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "cacib-sat-bastion-publicIP"
    location                     = var.location
    resource_group_name          = "${azurerm_resource_group.myterraformgroup.name}"
    allocation_method            = "Dynamic"

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "cacib-ocp-public-sg"
    location            = var.location
    resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"
    
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

# Create primary network interface
resource "azurerm_network_interface" "cacib_sat_bastion_vnic" {
    name                      = "cacib-sat-bastion-vnic"
    location                  = var.location
    resource_group_name       = "${azurerm_resource_group.myterraformgroup.name}"
    network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "cacib-sat-bastion-vnic-config"
        subnet_id                     = "${azurerm_subnet.cacib_ocp_public_subnet.id}"
        primary                       = true
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}"
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

resource "azurerm_network_interface" "myterraformprivatenic" {
    name                      = "cacib-sat-bastion-private-vnic"
    location                  = var.location
    resource_group_name       = "${azurerm_resource_group.myterraformgroup.name}"
    # network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "cacib-sat-bastion-private-vnic-config"
        subnet_id                     = "${azurerm_subnet.myterraformprivatesubnet.id}"
        private_ip_address_allocation = "Dynamic"
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.myterraformgroup.name}"
    }
    
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.myterraformgroup.name}"
    location                    = var.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}
# Create virtual machine
resource "azurerm_virtual_machine" "cacib_sat_bastion_vm" {
    name                  = "cacib-sat-bastion"
    location              = var.location
    resource_group_name   = "${azurerm_resource_group.myterraformgroup.name}"
    network_interface_ids = ["${azurerm_network_interface.cacib_sat_bastion_vnic.id}", "${azurerm_network_interface.myterraformprivatenic.id}"]
    vm_size               = var.bastion_vm_size

    primary_network_interface_id     = "${azurerm_network_interface.cacib_sat_bastion_vnic.id}"
    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true

    storage_os_disk {
        name              = "cacib-sat-bastion-osdisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_image_reference {
        publisher = "RedHat"
        offer     = "RHEL"
        sku       = "7.7"
        version   = "latest"
    }

    os_profile {
        computer_name  = "cacib-sat-bastion"
        admin_username = "xymox"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/xymox/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDUyJTU41oHiKUNzlwimge7n/3T12fqZKLUO5oanFPHEoaFw3FUOkjflmHhm7AiBJnHmQrOGgv7zZqVX7U8ST2Y4Nk6Se4RCMJSXzFZVh113KE7s+z5GvWQ8bNwdI6w7I/KE3sZPG0vowERI2SZagyRfRiYJ4y5OF/E0N7p9qBeIgQIypQniAq6a9J1jBUB5lGL+DY1XgqtdMiWIBYVyPcy1Rjd5FpHwuTlUCco/l29lbnRd2C9uzqPmsM2XGF5iu82N+JuV4cOjbu4A9SeAmjRHeUp+wvEoxXRm2jukp587FDCcm2mskZ3Oip+RZ7ROOc9QxiEpWXfG8yt/VwYZkjJ"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

resource "azurerm_network_interface" "cacib_ocp_master0_private_nic" {
    name                      = "cacib-ocp-master0-private-vnic"
    location                  = var.location
    resource_group_name       = "${azurerm_resource_group.myterraformgroup.name}"
    # network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "cacib-ocp-master0-private-vnic-config"
        subnet_id                     = "${azurerm_subnet.myterraformprivatesubnet.id}"
        private_ip_address_allocation = "Dynamic"
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}


# Create private virtual machine
resource "azurerm_virtual_machine" "cacib_ocp_master0_vm" {
    name                  = "cacib-ocp-master0"
    location              = var.location
    resource_group_name   = "${azurerm_resource_group.myterraformgroup.name}"
    network_interface_ids = ["${azurerm_network_interface.cacib_ocp_master0_private_nic.id}"]
    vm_size               = var.master_vm_size

    primary_network_interface_id     = "${azurerm_network_interface.cacib_ocp_master0_private_nic.id}"
    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true

    storage_os_disk {
        name              = "cacib-ocp-master0-osdisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_image_reference {
        publisher = "RedHat"
        offer     = "RHEL"
        sku       = "7.7"
        version   = "latest"
    }

    os_profile {
        computer_name  = "cacib-ocp-master0"
        admin_username = "xymox"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/xymox/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDUyJTU41oHiKUNzlwimge7n/3T12fqZKLUO5oanFPHEoaFw3FUOkjflmHhm7AiBJnHmQrOGgv7zZqVX7U8ST2Y4Nk6Se4RCMJSXzFZVh113KE7s+z5GvWQ8bNwdI6w7I/KE3sZPG0vowERI2SZagyRfRiYJ4y5OF/E0N7p9qBeIgQIypQniAq6a9J1jBUB5lGL+DY1XgqtdMiWIBYVyPcy1Rjd5FpHwuTlUCco/l29lbnRd2C9uzqPmsM2XGF5iu82N+JuV4cOjbu4A9SeAmjRHeUp+wvEoxXRm2jukp587FDCcm2mskZ3Oip+RZ7ROOc9QxiEpWXfG8yt/VwYZkjJ"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}


resource "azurerm_network_interface" "cacib_bastion_public_vnic" {
    name                      = "cacib-bastion-public_vnic"
    location                  = var.location
    resource_group_name       = "${azurerm_resource_group.myterraformgroup.name}"
    network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "cacib-sat-bastion-vnic-config"
        subnet_id                     = "${azurerm_subnet.cacib_ocp_public_subnet.id}"
        primary                       = true
        private_ip_address_allocation = "Dynamic"
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

resource "azurerm_network_interface" "cacib_bastion_private_vnic" {
    name                      = "cacib-bastion-private-vnic"
    location                  = var.location
    resource_group_name       = "${azurerm_resource_group.myterraformgroup.name}"
    # network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "cacib-bastion-private-vnic-config"
        subnet_id                     = "${azurerm_subnet.myterraformprivatesubnet.id}"
        private_ip_address_allocation = "Dynamic"
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

# Create virtual machine registry
resource "azurerm_virtual_machine" "cacib_bastion_vm" {
    name                  = "cacib-bastion"
    location              = var.location
    resource_group_name   = "${azurerm_resource_group.myterraformgroup.name}"
    network_interface_ids = ["${azurerm_network_interface.cacib_bastion_public_vnic.id}", "${azurerm_network_interface.cacib_bastion_private_vnic.id}"]
    vm_size               = var.bastion_vm_size

    primary_network_interface_id     = "${azurerm_network_interface.cacib_bastion_public_vnic.id}"
    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true

    storage_os_disk {
        name              = "cacib-bastion-osdisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    storage_image_reference {
        publisher = "RedHat"
        offer     = "RHEL"
        sku       = "7.7"
        version   = "latest"
    }

    os_profile {
        computer_name  = "cacib-bastion"
        admin_username = "xymox"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/xymox/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDUyJTU41oHiKUNzlwimge7n/3T12fqZKLUO5oanFPHEoaFw3FUOkjflmHhm7AiBJnHmQrOGgv7zZqVX7U8ST2Y4Nk6Se4RCMJSXzFZVh113KE7s+z5GvWQ8bNwdI6w7I/KE3sZPG0vowERI2SZagyRfRiYJ4y5OF/E0N7p9qBeIgQIypQniAq6a9J1jBUB5lGL+DY1XgqtdMiWIBYVyPcy1Rjd5FpHwuTlUCco/l29lbnRd2C9uzqPmsM2XGF5iu82N+JuV4cOjbu4A9SeAmjRHeUp+wvEoxXRm2jukp587FDCcm2mskZ3Oip+RZ7ROOc9QxiEpWXfG8yt/VwYZkjJ"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}


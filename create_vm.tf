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

variable "worker_vm_size" {
  default = "Standard_D4s_v3"
}

variable "master_count" {
  default = 3
}

variable "worker_count" {
  default = 3
}

variable "address_space" {
  default = "10.5.0.0/16"
}

variable "resource_group_name" {
  default = "cacib-ocp-disconnected-install-rg"
}

variable "admin_username" {
  default = "ocpadmin"
}

variable "ssh_key_private" {
  default = "~/.ssh/id_rsa"
}

resource "null_resource" "reset_ip_addresses" {
  provisioner "local-exec" {
    command = "rm -f private-ips.txt"
  }
}

resource "azurerm_resource_group" "cacib_ocp_group" {
    name     = var.resource_group_name
    location = var.location

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "cacib-ocp-public-vnet"
    address_space       = [var.address_space]
    location            = var.location
    resource_group_name = "${azurerm_resource_group.cacib_ocp_group.name}"

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

# Create primary subnet
resource "azurerm_subnet" "cacib_ocp_public_subnet" {
    name                 = "cacib-ocp-public-subnet"
    resource_group_name  = "${azurerm_resource_group.cacib_ocp_group.name}"
    virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
    address_prefix       = cidrsubnet(var.address_space, 8, 1)
}

# Create private subnet
resource "azurerm_subnet" "myterraformprivatesubnet" {
    name                 = "cacib-ocp-private-subnet"
    resource_group_name  = "${azurerm_resource_group.cacib_ocp_group.name}"
    virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
    route_table_id       = "${azurerm_route_table.cacibprivateroutetable.id}"
    address_prefix       = cidrsubnet(var.address_space, 8, 2)
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "cacib-sat-publicIP"
    location                     = var.location
    resource_group_name          = "${azurerm_resource_group.cacib_ocp_group.name}"
    allocation_method            = "Dynamic"

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "cacib-ocp-public-sg"
    location            = var.location
    resource_group_name = "${azurerm_resource_group.cacib_ocp_group.name}"
    
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
resource "azurerm_network_interface" "cacib_sat_vnic" {
    name                      = "cacib-sat-vnic"
    location                  = var.location
    resource_group_name       = "${azurerm_resource_group.cacib_ocp_group.name}"
    network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "cacib-sat-vnic-config"
        subnet_id                     = "${azurerm_subnet.cacib_ocp_public_subnet.id}"
        primary                       = true
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}"
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

resource "azurerm_network_interface" "cacib_sat_private_vnic" {
    name                      = "cacib-sat-private-vnic"
    location                  = var.location
    resource_group_name       = "${azurerm_resource_group.cacib_ocp_group.name}"
    # network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "cacib-sat-private-vnic-config"
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
        resource_group = "${azurerm_resource_group.cacib_ocp_group.name}"
    }
    
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.cacib_ocp_group.name}"
    location                    = var.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

#
# Retrieve public ip for test vm
#
data "azurerm_public_ip" "cacib_sat_vm_public_ip" {
  name                  = "${azurerm_public_ip.myterraformpublicip.name}"
  resource_group_name   = "${azurerm_resource_group.cacib_ocp_group.name}"
}


# Create virtual machine
resource "azurerm_virtual_machine" "cacib_sat_vm" {
    name                  = "cacib-sat"
    location              = var.location
    resource_group_name   = "${azurerm_resource_group.cacib_ocp_group.name}"
    network_interface_ids = ["${azurerm_network_interface.cacib_sat_vnic.id}", "${azurerm_network_interface.cacib_sat_private_vnic.id}"]
    vm_size               = var.bastion_vm_size

    primary_network_interface_id     = "${azurerm_network_interface.cacib_sat_vnic.id}"
    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true

    storage_os_disk {
        name              = "cacib-sat-osdisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "StandardSSD_LRS"
    }

    storage_image_reference {
        publisher = "RedHat"
        offer     = "RHEL"
        sku       = "7.7"
        version   = "latest"
    }

    os_profile {
        computer_name  = "cacib-sat"
        admin_username = var.admin_username
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/${var.admin_username}/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDUyJTU41oHiKUNzlwimge7n/3T12fqZKLUO5oanFPHEoaFw3FUOkjflmHhm7AiBJnHmQrOGgv7zZqVX7U8ST2Y4Nk6Se4RCMJSXzFZVh113KE7s+z5GvWQ8bNwdI6w7I/KE3sZPG0vowERI2SZagyRfRiYJ4y5OF/E0N7p9qBeIgQIypQniAq6a9J1jBUB5lGL+DY1XgqtdMiWIBYVyPcy1Rjd5FpHwuTlUCco/l29lbnRd2C9uzqPmsM2XGF5iu82N+JuV4cOjbu4A9SeAmjRHeUp+wvEoxXRm2jukp587FDCcm2mskZ3Oip+RZ7ROOc9QxiEpWXfG8yt/VwYZkjJ"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    provisioner "remote-exec" {
      inline = ["touch /var/tmp/terraform.done"]

      connection {
        type        = "ssh"
        user        = var.admin_username
        host = "${data.azurerm_public_ip.cacib_sat_vm_public_ip.ip_address}"
        private_key = "${file(var.ssh_key_private)}"
      }
    }

    provisioner "local-exec" {
      command = "echo ${azurerm_network_interface.cacib_sat_private_vnic.ip_configuration[0].private_ip_address} ${self.name} >> private-ips.txt"
    }

    provisioner "local-exec" {
      command = "ansible-playbook -u ${var.admin_username} -i '${data.azurerm_public_ip.cacib_sat_vm_public_ip.ip_address},' --private-key ${var.ssh_key_private} ansible/subscription-register.yaml" 
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

resource "azurerm_network_interface" "cacib_ocp_master_private_nic" {
    count                     = var.master_count
    name                      = "cacib-ocp-master${count.index}-private-vnic"
    location                  = var.location
    resource_group_name       = "${azurerm_resource_group.cacib_ocp_group.name}"
    # network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "cacib-ocp-master${count.index}-private-vnic-config"
        subnet_id                     = "${azurerm_subnet.myterraformprivatesubnet.id}"
        private_ip_address_allocation = "Static"
        private_ip_address            = cidrhost(var.address_space, count.index+552)
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}


# Create private virtual machine
resource "azurerm_virtual_machine" "cacib_ocp_master_vm" {
    count                 = var.master_count
    name                  = "cacib-ocp-master${count.index}"
    location              = var.location
    resource_group_name   = "${azurerm_resource_group.cacib_ocp_group.name}"
    network_interface_ids = ["${azurerm_network_interface.cacib_ocp_master_private_nic[count.index].id}"]
    vm_size               = var.master_vm_size

    primary_network_interface_id     = "${azurerm_network_interface.cacib_ocp_master_private_nic[count.index].id}"
    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true

    storage_os_disk {
        name              = "cacib-ocp-master${count.index}-osdisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "StandardSSD_LRS"
    }

    storage_image_reference {
        publisher = "RedHat"
        offer     = "RHEL"
        sku       = "7.7"
        version   = "latest"
    }

    os_profile {
        computer_name  = "cacib-ocp-master${count.index}"
        admin_username = var.admin_username
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/${var.admin_username}/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDUyJTU41oHiKUNzlwimge7n/3T12fqZKLUO5oanFPHEoaFw3FUOkjflmHhm7AiBJnHmQrOGgv7zZqVX7U8ST2Y4Nk6Se4RCMJSXzFZVh113KE7s+z5GvWQ8bNwdI6w7I/KE3sZPG0vowERI2SZagyRfRiYJ4y5OF/E0N7p9qBeIgQIypQniAq6a9J1jBUB5lGL+DY1XgqtdMiWIBYVyPcy1Rjd5FpHwuTlUCco/l29lbnRd2C9uzqPmsM2XGF5iu82N+JuV4cOjbu4A9SeAmjRHeUp+wvEoxXRm2jukp587FDCcm2mskZ3Oip+RZ7ROOc9QxiEpWXfG8yt/VwYZkjJ"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    provisioner "local-exec" {
      command = "echo ${azurerm_network_interface.cacib_ocp_master_private_nic[count.index].ip_configuration[0].private_ip_address} ${self.name} >> private-ips.txt"
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}


resource "azurerm_network_interface" "cacib_bastion_public_vnic" {
    name                      = "cacib-bastion-public_vnic"
    location                  = var.location
    resource_group_name       = "${azurerm_resource_group.cacib_ocp_group.name}"
    network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "cacib-sat-vnic-config"
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
    resource_group_name       = "${azurerm_resource_group.cacib_ocp_group.name}"
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
    resource_group_name   = "${azurerm_resource_group.cacib_ocp_group.name}"
    network_interface_ids = ["${azurerm_network_interface.cacib_bastion_public_vnic.id}", "${azurerm_network_interface.cacib_bastion_private_vnic.id}"]
    vm_size               = var.bastion_vm_size

    primary_network_interface_id     = "${azurerm_network_interface.cacib_bastion_public_vnic.id}"
    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true

    storage_os_disk {
        name              = "cacib-bastion-osdisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "StandardSSD_LRS"
    }

    storage_image_reference {
        publisher = "RedHat"
        offer     = "RHEL"
        sku       = "7.7"
        version   = "latest"
    }

    os_profile {
        computer_name  = "cacib-bastion"
        admin_username = var.admin_username
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/${var.admin_username}/.ssh/authorized_keys"
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

resource "azurerm_network_interface" "cacib_ocp_worker_private_nic" {
    count                     = var.worker_count
    name                      = "cacib-ocp-worker${count.index}-private-vnic"
    location                  = var.location
    resource_group_name       = "${azurerm_resource_group.cacib_ocp_group.name}"
    # network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "cacib-ocp-worker${count.index}-private-vnic-config"
        subnet_id                     = "${azurerm_subnet.myterraformprivatesubnet.id}"
        private_ip_address_allocation = "Static"
        private_ip_address            = cidrhost(var.address_space, count.index+532)
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}


# Create private virtual machine
resource "azurerm_virtual_machine" "cacib_ocp_worker_vm" {
    count                 = var.worker_count
    name                  = "cacib-ocp-worker${count.index}"
    location              = var.location
    resource_group_name   = "${azurerm_resource_group.cacib_ocp_group.name}"
    network_interface_ids = ["${azurerm_network_interface.cacib_ocp_worker_private_nic[count.index].id}"]
    vm_size               = var.worker_vm_size

    primary_network_interface_id     = "${azurerm_network_interface.cacib_ocp_worker_private_nic[count.index].id}"
    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true

    storage_os_disk {
        name              = "cacib-ocp-worker${count.index}-osdisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "StandardSSD_LRS"
    }

    storage_image_reference {
        publisher = "RedHat"
        offer     = "RHEL"
        sku       = "7.7"
        version   = "latest"
    }

    os_profile {
        computer_name  = "cacib-ocp-worker${count.index}"
        admin_username = var.admin_username
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/${var.admin_username}/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDUyJTU41oHiKUNzlwimge7n/3T12fqZKLUO5oanFPHEoaFw3FUOkjflmHhm7AiBJnHmQrOGgv7zZqVX7U8ST2Y4Nk6Se4RCMJSXzFZVh113KE7s+z5GvWQ8bNwdI6w7I/KE3sZPG0vowERI2SZagyRfRiYJ4y5OF/E0N7p9qBeIgQIypQniAq6a9J1jBUB5lGL+DY1XgqtdMiWIBYVyPcy1Rjd5FpHwuTlUCco/l29lbnRd2C9uzqPmsM2XGF5iu82N+JuV4cOjbu4A9SeAmjRHeUp+wvEoxXRm2jukp587FDCcm2mskZ3Oip+RZ7ROOc9QxiEpWXfG8yt/VwYZkjJ"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    provisioner "local-exec" {
      command = "echo ${azurerm_network_interface.cacib_ocp_worker_private_nic[count.index].ip_configuration[0].private_ip_address} ${self.name} >> private-ips.txt"
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

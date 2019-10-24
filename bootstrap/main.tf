# Create a resource group if it doesn’t exist

### # Create virtual network
### resource "azurerm_virtual_network" "myterraformnetwork" {
###     name                = "cacib-ocp-public-vnet"
###     address_space       = [var.address_space]
###     location            = var.location
###     resource_group_name = "${azurerm_resource_group.cacib_ocp_group.name}"
### 
###     tags = {
###         environment = "CA-CIB OCP Terraform Setup"
###     }
### }
### 
### # Create primary subnet
### resource "azurerm_subnet" "cacib_ocp_public_subnet" {
###     name                 = "cacib-ocp-public-subnet"
###     resource_group_name  = "${azurerm_resource_group.cacib_ocp_group.name}"
###     virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
###     address_prefix       = cidrsubnet(var.address_space, 8, 1)
### }
### 
### # Create private subnet
### resource "azurerm_subnet" "myterraformprivatesubnet" {
###     name                 = "cacib-ocp-private-subnet"
###     resource_group_name  = "${azurerm_resource_group.cacib_ocp_group.name}"
###     virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
###     route_table_id       = "${azurerm_route_table.cacibprivateroutetable.id}"
###     address_prefix       = cidrsubnet(var.address_space, 8, 2)
### }
### 
### # Create Network Security Group and rule
### resource "azurerm_network_security_group" "myterraformnsg" {
###     name                = "cacib-ocp-public-sg"
###     location            = var.location
###     resource_group_name = "${azurerm_resource_group.cacib_ocp_group.name}"
###     
###     security_rule {
###         name                       = "SSH"
###         priority                   = 1001
###         direction                  = "Inbound"
###         access                     = "Allow"
###         protocol                   = "Tcp"
###         source_port_range          = "*"
###         destination_port_range     = "22"
###         source_address_prefix      = "*"
###         destination_address_prefix = "*"
###     }
### 
###     security_rule {
###         name                       = "HTTPS"
###         priority                   = 1011
###         direction                  = "Inbound"
###         access                     = "Allow"
###         protocol                   = "Tcp"
###         source_port_range          = "*"
###         destination_port_range     = "443"
###         source_address_prefix      = "*"
###         destination_address_prefix = "*"
###     }
### 
###     security_rule {
###         name                       = "HTTP"
###         priority                   = 1021
###         direction                  = "Inbound"
###         access                     = "Allow"
###         protocol                   = "Tcp"
###         source_port_range          = "*"
###         destination_port_range     = "80"
###         source_address_prefix      = "*"
###         destination_address_prefix = "*"
###     }
### 
###     tags = {
###         environment = "CA-CIB OCP Terraform Setup"
###     }
### }
### 
# Create primary network interface
resource "azurerm_network_interface" "cacib_sat_vnic" {
    name                      = "cacib-sat-vnic"
    location                  = var.region
    resource_group_name       = var.resource_group_name
    network_security_group_id = var.nsg_name

    ip_configuration {
        name                          = "cacib-sat-vnic-config"
        subnet_id                     = var.public_subnet_id
        primary                       = true
        private_ip_address_allocation = "Dynamic"
        #
        # TODO check if ocp is using public_ip_address (or lb). Use association if possible.
        #
        public_ip_address_id          = var.public_ip_address_id
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

resource "azurerm_network_interface" "cacib_sat_private_vnic" {
    name                      = "cacib-sat-private-vnic"
    location                  = var.region
    resource_group_name       = var.resource_group_name
    # network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "cacib-sat-private-vnic-config"
        subnet_id                     = var.private_subnet_id
        private_ip_address_allocation = "Dynamic"
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}
 
### # Generate random text for a unique storage account name
### resource "random_id" "randomId" {
###     keepers = {
###         # Generate a new ID only when a new resource group is defined
###         resource_group = "${azurerm_resource_group.cacib_ocp_group.name}"
###     }
###     
###     byte_length = 8
### }
### 
### # Create storage account for boot diagnostics
### resource "azurerm_storage_account" "mystorageaccount" {
###     name                        = "diag${random_id.randomId.hex}"
###     resource_group_name         = "${azurerm_resource_group.cacib_ocp_group.name}"
###     location                    = var.location
###     account_tier                = "Standard"
###     account_replication_type    = "LRS"
### 
###     tags = {
###         environment = "CA-CIB OCP Terraform Setup"
###     }
### }
### 
### #
### # Retrieve public ip for test vm
### #
### data "azurerm_public_ip" "cacib_sat_vm_public_ip" {
###   name                  = "${azurerm_public_ip.myterraformpublicip.name}"
###   resource_group_name   = "${azurerm_resource_group.cacib_ocp_group.name}"
### }
### 
### 

#
# Retrieve public ip for test vm
# TODO: refactor this ASAP
#
data "azurerm_public_ip" "bootstrap" {
  name                  = var.public_ip_address_name
  resource_group_name   = var.resource_group_name
}

# Create virtual machine
resource "azurerm_virtual_machine" "cacib_sat_vm" {
    name                  = "cacib-sat"
    location              = var.region
    resource_group_name   = var.resource_group_name
    network_interface_ids = ["${azurerm_network_interface.cacib_sat_vnic.id}", "${azurerm_network_interface.cacib_sat_private_vnic.id}"]
    vm_size               = var.vm_size

    primary_network_interface_id     = "${azurerm_network_interface.cacib_sat_vnic.id}"
    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true

    storage_os_disk {
      name              = "cacib-sat-osdisk"
      caching           = "ReadWrite"
      create_option     = "FromImage"
      managed_disk_type = "StandardSSD_LRS"
      disk_size_gb      = "1023"
    }

    storage_data_disk {
      name              = "datadisk_sat"
      managed_disk_type = "StandardSSD_LRS"
      create_option     = "Empty"
      lun               = 0
      disk_size_gb      = "256"
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
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDjzKjT3BPuKofK2hOIEV7jghNxi+WH6+eaMkgl+U3h32XvR/koBHBWH4p1LFktGRQwDh/oSz8C0huqt2TOIA8S6YlX5jbyUaCCPWMQd4OaQ2wfu+GfECJkd8w/A4wgYomaG+ZI2IJTaq4vOMctrdIRuaNxCcAiVcYxbV9Pc3ndKifn0wmcENGHz78k2mak0FiPg10OyNEbhkNGTtAmdeDZf06Q0ml9K/7iA8+qgxKRB8/zAficI/BcqgT2NAnYvuwWYeg920cmqg94oIMN7EsVtSio7RV+d+nJo2kzgh1zR7Ss4aKxuNYvgx4BPZ4GcJSMFnE98hr75IDBnRG0Ut+D"
        }
    }

    boot_diagnostics {
        enabled     = "true"
        storage_uri = var.storage_account.primary_blob_endpoint
    }

    provisioner "remote-exec" {
      inline = ["touch /var/tmp/terraform.done"]

      connection {
        type        = "ssh"
        user        = var.admin_username
        host        = "${data.azurerm_public_ip.bootstrap.ip_address}"
        private_key = "${file(var.ssh_key_private)}"
        agent       = true
        timeout     = "8m"
      }

      on_failure = "continue"
    }

    provisioner "local-exec" {
      command = "echo ${azurerm_network_interface.cacib_sat_private_vnic.ip_configuration[0].private_ip_address} ${self.name} >> private-ips.txt"
    }

    provisioner "local-exec" {
      command = "ansible-playbook -u ${var.admin_username} -i '${data.azurerm_public_ip.bootstrap.ip_address},' --private-key ${var.ssh_key_private} ansible/subscription-register.yaml" 
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

### resource "azurerm_network_interface" "cacib_ocp_master_private_nic" {
###     count                     = var.master_count
###     name                      = "cacib-ocp-master${count.index}-private-vnic"
###     location                  = var.location
###     resource_group_name       = "${azurerm_resource_group.cacib_ocp_group.name}"
###     # network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"
### 
###     ip_configuration {
###         name                          = "cacib-ocp-master${count.index}-private-vnic-config"
###         subnet_id                     = "${azurerm_subnet.myterraformprivatesubnet.id}"
###         private_ip_address_allocation = "Static"
###         private_ip_address            = cidrhost(var.address_space, count.index+552)
###     }
### 
###     tags = {
###         environment = "CA-CIB OCP Terraform Setup"
###     }
### }
### 
### 
### # Create private virtual machine
### resource "azurerm_virtual_machine" "cacib_ocp_master_vm" {
###     count                 = var.master_count
###     name                  = "cacib-ocp-master${count.index}"
###     location              = var.location
###     resource_group_name   = "${azurerm_resource_group.cacib_ocp_group.name}"
###     network_interface_ids = ["${azurerm_network_interface.cacib_ocp_master_private_nic[count.index].id}"]
###     vm_size               = var.master_vm_size
### 
###     primary_network_interface_id     = "${azurerm_network_interface.cacib_ocp_master_private_nic[count.index].id}"
###     delete_os_disk_on_termination    = true
###     delete_data_disks_on_termination = true
### 
###     storage_os_disk {
###         name              = "cacib-ocp-master${count.index}-osdisk"
###         caching           = "ReadWrite"
###         create_option     = "FromImage"
###         managed_disk_type = "StandardSSD_LRS"
###     }
### 
###     storage_image_reference {
###         publisher = "RedHat"
###         offer     = "RHEL"
###         sku       = "7.7"
###         version   = "latest"
###     }
### 
###     os_profile {
###         computer_name  = "cacib-ocp-master${count.index}"
###         admin_username = var.admin_username
###     }
### 
###     os_profile_linux_config {
###         disable_password_authentication = true
###         ssh_keys {
###             path     = "/home/${var.admin_username}/.ssh/authorized_keys"
###             key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDUyJTU41oHiKUNzlwimge7n/3T12fqZKLUO5oanFPHEoaFw3FUOkjflmHhm7AiBJnHmQrOGgv7zZqVX7U8ST2Y4Nk6Se4RCMJSXzFZVh113KE7s+z5GvWQ8bNwdI6w7I/KE3sZPG0vowERI2SZagyRfRiYJ4y5OF/E0N7p9qBeIgQIypQniAq6a9J1jBUB5lGL+DY1XgqtdMiWIBYVyPcy1Rjd5FpHwuTlUCco/l29lbnRd2C9uzqPmsM2XGF5iu82N+JuV4cOjbu4A9SeAmjRHeUp+wvEoxXRm2jukp587FDCcm2mskZ3Oip+RZ7ROOc9QxiEpWXfG8yt/VwYZkjJ"
###         }
###     }
### 
###     boot_diagnostics {
###         enabled = "true"
###         storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
###     }
### 
###     provisioner "local-exec" {
###       command = "echo ${azurerm_network_interface.cacib_ocp_master_private_nic[count.index].ip_configuration[0].private_ip_address} ${self.name} >> private-ips.txt"
###     }
### 
###     tags = {
###         environment = "CA-CIB OCP Terraform Setup"
###     }
### }
### 
### 
### resource "azurerm_network_interface" "cacib_bastion_public_vnic" {
###     name                      = "cacib-bastion-public_vnic"
###     location                  = var.location
###     resource_group_name       = "${azurerm_resource_group.cacib_ocp_group.name}"
###     network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"
### 
###     ip_configuration {
###         name                          = "cacib-sat-vnic-config"
###         subnet_id                     = "${azurerm_subnet.cacib_ocp_public_subnet.id}"
###         primary                       = true
###         private_ip_address_allocation = "Dynamic"
###     }
### 
###     tags = {
###         environment = "CA-CIB OCP Terraform Setup"
###     }
### }
### 
### resource "azurerm_network_interface" "cacib_bastion_private_vnic" {
###     name                      = "cacib-bastion-private-vnic"
###     location                  = var.location
###     resource_group_name       = "${azurerm_resource_group.cacib_ocp_group.name}"
###     # network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"
### 
###     ip_configuration {
###         name                          = "cacib-bastion-private-vnic-config"
###         subnet_id                     = "${azurerm_subnet.myterraformprivatesubnet.id}"
###         private_ip_address_allocation = "Dynamic"
###     }
### 
###     tags = {
###         environment = "CA-CIB OCP Terraform Setup"
###     }
### }
### 
### # Create virtual machine registry
### resource "azurerm_virtual_machine" "cacib_bastion_vm" {
###     name                  = "cacib-bastion"
###     location              = var.location
###     resource_group_name   = "${azurerm_resource_group.cacib_ocp_group.name}"
###     network_interface_ids = ["${azurerm_network_interface.cacib_bastion_public_vnic.id}", "${azurerm_network_interface.cacib_bastion_private_vnic.id}"]
###     vm_size               = var.bastion_vm_size
### 
###     primary_network_interface_id     = "${azurerm_network_interface.cacib_bastion_public_vnic.id}"
###     delete_os_disk_on_termination    = true
###     delete_data_disks_on_termination = true
### 
###     storage_os_disk {
###         name              = "cacib-bastion-osdisk"
###         caching           = "ReadWrite"
###         create_option     = "FromImage"
###         managed_disk_type = "StandardSSD_LRS"
###     }
### 
###     storage_image_reference {
###         publisher = "RedHat"
###         offer     = "RHEL"
###         sku       = "7.7"
###         version   = "latest"
###     }
### 
###     os_profile {
###         computer_name  = "cacib-bastion"
###         admin_username = var.admin_username
###     }
### 
###     os_profile_linux_config {
###         disable_password_authentication = true
###         ssh_keys {
###             path     = "/home/${var.admin_username}/.ssh/authorized_keys"
###             key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDUyJTU41oHiKUNzlwimge7n/3T12fqZKLUO5oanFPHEoaFw3FUOkjflmHhm7AiBJnHmQrOGgv7zZqVX7U8ST2Y4Nk6Se4RCMJSXzFZVh113KE7s+z5GvWQ8bNwdI6w7I/KE3sZPG0vowERI2SZagyRfRiYJ4y5OF/E0N7p9qBeIgQIypQniAq6a9J1jBUB5lGL+DY1XgqtdMiWIBYVyPcy1Rjd5FpHwuTlUCco/l29lbnRd2C9uzqPmsM2XGF5iu82N+JuV4cOjbu4A9SeAmjRHeUp+wvEoxXRm2jukp587FDCcm2mskZ3Oip+RZ7ROOc9QxiEpWXfG8yt/VwYZkjJ"
###         }
###     }
### 
###     boot_diagnostics {
###         enabled = "true"
###         storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
###     }
### 
###     tags = {
###         environment = "CA-CIB OCP Terraform Setup"
###     }
### }
### 
### resource "azurerm_network_interface" "cacib_ocp_worker_private_nic" {
###     count                     = var.worker_count
###     name                      = "cacib-ocp-worker${count.index}-private-vnic"
###     location                  = var.location
###     resource_group_name       = "${azurerm_resource_group.cacib_ocp_group.name}"
###     # network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"
### 
###     ip_configuration {
###         name                          = "cacib-ocp-worker${count.index}-private-vnic-config"
###         subnet_id                     = "${azurerm_subnet.myterraformprivatesubnet.id}"
###         private_ip_address_allocation = "Static"
###         private_ip_address            = cidrhost(var.address_space, count.index+532)
###     }
### 
###     tags = {
###         environment = "CA-CIB OCP Terraform Setup"
###     }
### }

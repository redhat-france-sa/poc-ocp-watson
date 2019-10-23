variable "address_space" {
  default = "10.5.0.0/16"
}

resource "azurerm_network_interface" "cacib_bastion_public_vnic" {
    name                      = "cacib-bastion-public_vnic"
    location                  = var.region
    resource_group_name       = var.resource_group_name
    network_security_group_id = var.nsg_name

    ip_configuration {
        name                          = "cacib-sat-vnic-config"
        subnet_id                     = var.public_subnet_id
        primary                       = true
        private_ip_address_allocation = "Dynamic"
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

resource "azurerm_network_interface" "cacib_bastion_private_vnic" {
    name                      = "cacib-bastion-private-vnic"
    location                  = var.region
    resource_group_name       = var.resource_group_name

    ip_configuration {
        name                          = "cacib-bastion-private-vnic-config"
        subnet_id                     = var.private_subnet_id
        private_ip_address_allocation = "Dynamic"
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

# Create virtual machine registry
resource "azurerm_virtual_machine" "cacib_bastion_vm" {
    name                  = "cacib-bastion"
    location              = var.region
    resource_group_name   = var.resource_group_name
    network_interface_ids = ["${azurerm_network_interface.cacib_bastion_public_vnic.id}", "${azurerm_network_interface.cacib_bastion_private_vnic.id}"]
    vm_size               = var.vm_size

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
      storage_uri = var.storage_account.primary_blob_endpoint
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}

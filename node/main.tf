resource "azurerm_network_interface" "node@G_private_nic" {
    count                     = var.instance_count
 
    name                      = "node@G${count.index}-private-vnic"
    location                  = var.region
    resource_group_name       = var.resource_group_name

    ip_configuration {
        name                          = "cacib-ocp-node@G${count.index}-private-vnic-config"
        subnet_id                     = var.private_subnet_id
        private_ip_address_allocation = "Static"
        private_ip_address            = cidrhost(var.address_space, count.index+552)
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}


# Create private virtual machine
resource "azurerm_virtual_machine" "cacib_ocp_node@G_vm" {
    count                     = var.instance_count
    name                      = "cacib-ocp-node@G${count.index}"
    location                  = var.region
    resource_group_name       = var.resource_group_name

    network_interface_ids = [element(azurerm_network_interface.node@G_private_nic.*.id, count.index)]
    vm_size               = var.vm_size

    primary_network_interface_id     = element(azurerm_network_interface.node@G_private_nic.*.id, count.index)

    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true

    storage_os_disk {
        name              = "cacib-ocp-node@G${count.index}-osdisk"
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
        computer_name  = "cacib-ocp-node@G${count.index}"
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

    provisioner "local-exec" {
      command = "echo ${azurerm_network_interface.node@G_private_nic[count.index].ip_configuration[0].private_ip_address} ${self.name} >> private-ips.txt"
    }

    tags = {
        environment = "CA-CIB OCP Terraform Setup"
    }
}


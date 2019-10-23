variable "vm_size" {
  type        = string
  description = "The SKU ID for the bootstrap node."
}

variable "region" {
  type        = string
  description = "The region for the deployment."
}

variable "resource_group_name" {
  type        = string
  description = "The resource group name for the deployment."
}

variable "storage_account" {
  type        = any
  description = "the storage account for the cluster. It can be used for boot diagnostics."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "tags to be applied to created resources."
}

variable "nsg_name" {
  type        = string
  description = "The network security group for the subnet."
}

variable "instance_count" {
  type = string
}

variable "public_subnet_id" {
  type        = string
  description = "The public subnet ID for the bootstrap node."
}

variable "private_subnet_id" {
  type        = string
  description = "The private subnet ID for the bootstrap node."
}

#
# added by xymox for this use
#

variable "address_space" {
  type        = string
  description = "The vnet address space."
}

variable "admin_username" {
  type        = string
  description = "The cluster admin username for ssh access."
}

variable "ssh_key_private" {
  type        = string
  description = "The private ssh key for ssh access."
}

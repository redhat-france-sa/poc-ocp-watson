variable "tags" {
  type        = map(string)
  default     = {}
  description = "tags to be applied to created resources."
}

variable "cluster_id" {
  description = "The identifier for the cluster."
  type        = string
}

variable "cluster_domain" {
  description = "The domain for the cluster that all DNS records must belong"
  type        = string
}

variable "base_domain" {
  description = "The base domain used for public records"
  type        = string
}

variable "base_domain_resource_group_name" {
  description = "The resource group where the base domain is"
  type        = string
}

variable "virtual_network_id" {
  description = "The ID for Virtual Network that will be linked to the Private DNS zone."
  type        = string
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the deployment"
}

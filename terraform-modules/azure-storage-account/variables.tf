variable "storage_account_name" {
  description = "Globally unique, 3-24 lowercase alphanumeric chars."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "replication_type" {
  type    = string
  default = "ZRS"
}

variable "containers" {
  type    = list(string)
  default = []
}

variable "public_network_access_enabled" {
  type    = bool
  default = false
}

variable "allowed_subnet_ids" {
  type    = list(string)
  default = []
}

variable "private_endpoint_subnet_id" {
  type    = string
  default = null
}

variable "blob_soft_delete_retention_days" {
  type    = number
  default = 14
}

variable "container_soft_delete_retention_days" {
  type    = number
  default = 14
}

variable "tags" {
  type    = map(string)
  default = {}
}

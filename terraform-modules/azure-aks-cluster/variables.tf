variable "cluster_name" {
  type = string
}

variable "dns_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "kubernetes_version" {
  description = "Pin explicitly; do not track 'latest' in production."
  type        = string
}

variable "sku_tier" {
  type    = string
  default = "Standard"
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Free, Standard, or Premium."
  }
}

variable "subnet_id" {
  description = "Subnet ID for node pools, typically the output of azure-networking."
  type        = string
}

variable "system_node_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "system_node_min_count" {
  type    = number
  default = 2
}

variable "system_node_max_count" {
  type    = number
  default = 4
}

variable "availability_zones" {
  type    = list(string)
  default = ["1", "2", "3"]
}

variable "log_analytics_workspace_id" {
  description = "Workspace ID for Defender + Container Insights (oms_agent)."
  type        = string
}

variable "workload_node_pools" {
  description = "Additional user node pools beyond the system pool."
  type        = map(object({
    vm_size     = string
    min_count   = number
    max_count   = number
    node_labels = optional(map(string), {})
    node_taints = optional(list(string), [])
  }))
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "create_resource_group" {
  description = "Whether this module should create its own resource group."
  type        = bool
  default     = true
}

variable "resource_group_name" {
  description = "Name of the resource group (created or existing, per create_resource_group)."
  type        = string
}

variable "location" {
  description = "Azure region, e.g. westeurope."
  type        = string
}

variable "name_prefix" {
  description = "Prefix applied to all resource names created by this module."
  type        = string
}

variable "address_space" {
  description = "CIDR address space for the virtual network."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "subnets" {
  description = "Map of subnets to create, each with its own address space, optional delegation, and NSG rules."
  type = map(object({
    address_prefixes = list(string)
    delegation = optional(object({
      name         = string
      service_name = string
      actions      = list(string)
    }))
    security_rules = optional(list(object({
      name                   = string
      priority               = number
      direction              = string
      access                 = string
      protocol               = string
      destination_port_range = string
      source_address_prefix  = string
    })), [])
  }))
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}

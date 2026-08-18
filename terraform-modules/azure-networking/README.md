# azure-networking

Reusable Terraform module for an Azure Virtual Network with per-subnet NSGs and
optional subnet delegation (e.g. for AKS, Container Instances, or PostgreSQL
Flexible Server).

## Why this module exists

Most Azure landing zones need the same networking primitives repeated per
environment: a VNet, a handful of subnets with different security postures,
and an NSG per subnet. This module makes that declarative and reusable
instead of hand-rolled per project.

## Usage

```hcl
module "networking" {
  source              = "../../terraform-modules/azure-networking"
  name_prefix         = "prod-euw"
  location            = "westeurope"
  resource_group_name = "rg-prod-networking"
  address_space       = ["10.30.0.0/16"]

  subnets = {
    aks = {
      address_prefixes = ["10.30.1.0/24"]
      security_rules = [
        {
          name                   = "allow-https-inbound"
          priority               = 100
          direction              = "Inbound"
          access                 = "Allow"
          protocol               = "Tcp"
          destination_port_range = "443"
          source_address_prefix  = "Internet"
        }
      ]
    }
    data = {
      address_prefixes = ["10.30.2.0/24"]
      delegation = {
        name         = "psql-delegation"
        service_name = "Microsoft.DBforPostgreSQL/flexibleServers"
        actions      = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }

  tags = {
    environment = "production"
    owner       = "platform-team"
  }
}
```

## Inputs / Outputs

Run `terraform-docs markdown . ` to regenerate a full table — kept out of
this README so it never drifts from `variables.tf` / `outputs.tf`.

## Design notes

- One NSG per subnet rather than one shared NSG, so blast radius of a bad
  rule change is scoped to a single subnet.
- `create_resource_group` defaults to `true` for standalone use, but can be
  set to `false` when composing this module inside a larger landing-zone
  root module that already owns the resource group.

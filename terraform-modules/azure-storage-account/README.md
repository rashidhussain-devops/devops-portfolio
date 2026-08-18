# azure-storage-account

Storage account hardened by default: shared-key auth disabled (Azure AD /
managed-identity only), TLS 1.2 minimum, network access denied by default
with an optional private endpoint, blob + container soft-delete, and
infrastructure (double) encryption.

## Usage

```hcl
module "app_storage" {
  source                     = "../../terraform-modules/azure-storage-account"
  storage_account_name       = "stprodeuwapp01"
  resource_group_name        = module.networking.resource_group_name
  location                   = "westeurope"
  containers                  = ["app-uploads", "backups"]
  private_endpoint_subnet_id = module.networking.subnet_ids["data"]

  tags = { environment = "production" }
}
```

## Design notes

`shared_access_key_enabled = false` is deliberate, not an oversight — it
forces every consumer (apps, CI, operators) onto Azure AD / managed identity
auth, which is auditable in Entra sign-in logs. If a third-party tool truly
requires a connection string, set this per-instance rather than changing the
module default.

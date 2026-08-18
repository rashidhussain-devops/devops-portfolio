# azure-aks-cluster

Opinionated AKS module: workload identity + OIDC federation instead of
service-principal secrets, Azure CNI Overlay with Cilium network policy,
Azure RBAC for Kubernetes authorization, and Defender + Container Insights
wired to a Log Analytics workspace by default.

## Why these defaults

- **Workload Identity over kubelet-managed secrets.** Pods authenticate to
  Azure via federated OIDC tokens, not stored client secrets — removes an
  entire class of credential-leak risk.
- **Azure CNI Overlay + Cilium.** Avoids exhausting VNet IP space at scale
  (a real constraint once you're running dozens of node pools) while keeping
  eBPF-based network policy enforcement.
- **`ignore_changes` on node_count.** Once cluster autoscaler is enabled,
  Terraform re-asserting a fixed node_count on every plan fights the
  autoscaler. Ignore it and let HPA/CA own that field.
- **Separate system and workload node pools.** System pool is tainted with
  `only_critical_addons_enabled`, so application pods never compete with
  CoreDNS/metrics-server for capacity during a noisy-neighbor event.

## Usage

```hcl
module "aks" {
  source                      = "../../terraform-modules/azure-aks-cluster"
  cluster_name                = "aks-prod-euw"
  dns_prefix                  = "aksprodeuw"
  resource_group_name         = module.networking.resource_group_name
  subnet_id                   = module.networking.subnet_ids["aks"]
  kubernetes_version           = "1.29.4"
  log_analytics_workspace_id  = azurerm_log_analytics_workspace.this.id

  workload_node_pools = {
    general = {
      vm_size   = "Standard_D8s_v5"
      min_count = 2
      max_count = 10
    }
    spot = {
      vm_size     = "Standard_D4s_v5"
      min_count   = 0
      max_count   = 6
      node_taints = ["kubernetes.azure.com/scalesetpriority=spot:NoSchedule"]
    }
  }

  tags = { environment = "production" }
}
```

## Post-provision

This module intentionally stops at the cluster boundary. Ingress
(NGINX/AGIC), GitOps bootstrap (ArgoCD/FluxCD), and the observability stack
are deployed separately via Helm — see `../../kubernetes-helm/`.

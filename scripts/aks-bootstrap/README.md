# aks-bootstrap

One-time imperative bootstrap for a new AKS cluster. Terraform provisions
the cluster and networking; this script installs the small set of
cluster-wide components that GitOps itself depends on (ingress controller,
cert-manager, ArgoCD), then hands off to the ArgoCD app-of-apps so every
subsequent change is a Git PR, not a `helm upgrade` from someone's laptop.

## Why this isn't in Terraform

Installing Helm releases via the Terraform `helm` provider works, but it
couples infrastructure state to application deployment state — a bad `helm
upgrade` inside a `terraform apply` can block or corrupt the Terraform state
lock. Keeping cluster bootstrap as an idempotent shell script run once
post-provision, then handing ongoing lifecycle to ArgoCD, keeps those
concerns separated.

## Usage

```bash
./bootstrap-cluster.sh aks-prod-euw rg-prod-networking
```

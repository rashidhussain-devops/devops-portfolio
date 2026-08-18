# kubernetes-helm

Two things live here:

1. **`charts/sample-webapp`** — a generic, production-leaning Helm chart
   (non-root containers, read-only rootfs, HPA, PDB, Workload Identity
   annotations, NGINX ingress + cert-manager) used as the base template for
   application charts.
2. **`gitops/argocd`** — an "app of apps" pattern: one root ArgoCD
   `Application` that points at a folder of child `Application` manifests,
   so adding a new service to the cluster is a PR that adds one YAML file,
   not a manual `argocd app create`.

## Local validation before pushing

```bash
helm lint charts/sample-webapp
helm template charts/sample-webapp | kubeconform -strict -summary
```

Both of these also run in CI — see `.github/workflows/helm-lint.yml`.

## Why app-of-apps

With a single cluster serving multiple apps, a flat list of ArgoCD
`Application` objects gets unwieldy fast, and RBAC/sync-wave ordering
becomes implicit. The app-of-apps pattern makes the set of deployed
applications itself GitOps-managed and diffable in a PR.

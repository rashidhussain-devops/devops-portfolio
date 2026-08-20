# GitOps Sync Layer — ArgoCD + FluxCD

After the initial migration (pipeline running `kubectl apply` directly —
still shown in [`../azure-devops/azure-pipelines-website.yml`](../azure-devops/azure-pipelines-website.yml)
as the first working version), the deployment step moved to a GitOps
model: the pipeline's job stops at updating the image tag in a manifests
repo, and ArgoCD/FluxCD take over actually reconciling the cluster to
match git.

## Why change a working deploy step

Direct `kubectl apply` from the pipeline means the pipeline is the only
thing that knows the cluster's intended state — if someone manually
patches a Deployment during an incident and forgets to revert it, nothing
notices the drift until the next pipeline run silently overwrites it (or
doesn't, if no one triggers one). `automated.selfHeal` in ArgoCD (and
`prune` in both tools) makes the cluster continuously self-correcting
against git, so git is unambiguously the source of truth rather than
"whatever the last pipeline run plus whatever anyone did after it" being
the de facto state.

## Why both ArgoCD and FluxCD show up here

Both are represented because both were genuinely evaluated and used for
different applications rather than one universal choice — ArgoCD's UI and
per-app visibility suited the applications actively being iterated on day
to day (like `qrcs-website`), while FluxCD's lighter footprint and
Kustomize-native model fit better for a more stable app that mostly just
needed drift correction without anyone actively watching a dashboard.
[`argocd/`](./argocd) and [`fluxcd/`](./fluxcd) show the same underlying
concept — a controller reconciling a namespace against a git path — in
each tool's actual syntax.

## Per-app aliases

[`scripts/gitops-aliases.sh`](./scripts/gitops-aliases.sh) — checking sync
status or forcing a reconcile shouldn't require remembering the exact app
name and namespace for every application in the fleet, especially during
an incident. One alias pair per app (`status-<app>`, `sync-<app>`) kept
this fast and consistent as more applications came onto GitOps.

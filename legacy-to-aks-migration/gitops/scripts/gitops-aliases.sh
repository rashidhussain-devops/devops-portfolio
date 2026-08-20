#!/usr/bin/env bash
#
# gitops-aliases.sh
#
# Per-application shortcuts for the ArgoCD/FluxCD-managed apps, so checking
# or forcing a sync doesn't mean re-typing the full app name and namespace
# every time. Source this from ~/.bashrc:
#   source ~/gitops-aliases.sh
#
# Add a new pair of aliases here whenever a new app gets onboarded to
# GitOps — keeps the muscle-memory command consistent across the whole
# application fleet instead of everyone remembering their own shortcuts.

# --- ArgoCD: status and manual sync, per app ---
alias status-website='argocd app get qrcs-website'
alias sync-website='argocd app sync qrcs-website'
alias logs-website='argocd app logs qrcs-website --follow'

alias status-crm='argocd app get qrcs-crm'
alias sync-crm='argocd app sync qrcs-crm'
alias logs-crm='argocd app logs qrcs-crm --follow'

# --- ArgoCD: everything at once ---
alias status-all='argocd app list'
alias sync-all='argocd app sync -l argocd.argoproj.io/instance'

# --- FluxCD equivalents, for the apps still on Flux ---
alias flux-status-website='flux get kustomization qrcs-website'
alias flux-reconcile-website='flux reconcile kustomization qrcs-website --with-source'

# --- kubectl shortcuts scoped to the production namespace, since typing
#     -n production on every command was the single most common typo
#     during incident response ---
alias kp='kubectl -n production get pods'
alias kd='kubectl -n production describe'
alias kl='kubectl -n production logs -f'

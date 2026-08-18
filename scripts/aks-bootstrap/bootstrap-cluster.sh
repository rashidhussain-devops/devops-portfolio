#!/usr/bin/env bash
#
# bootstrap-cluster.sh
#
# Post-provisioning bootstrap for a freshly created AKS cluster: wires up
# NGINX ingress, cert-manager, ArgoCD, and the Prometheus/Grafana stack via
# Helm, in dependency order. Intended to run once after `terraform apply`
# on the azure-aks-cluster module, before GitOps takes over ongoing sync.
#
# Usage:
#   ./bootstrap-cluster.sh <cluster-name> <resource-group>

set -euo pipefail

CLUSTER_NAME="${1:?Usage: $0 <cluster-name> <resource-group>}"
RESOURCE_GROUP="${2:?Usage: $0 <cluster-name> <resource-group>}"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }

log "Fetching AKS credentials"
az aks get-credentials --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --overwrite-existing

log "Adding Helm repositories"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

log "Installing ingress-nginx"
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
  --wait

log "Installing cert-manager (CRDs included)"
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true \
  --wait

log "Installing ArgoCD"
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --set server.service.type=ClusterIP \
  --wait

log "Installing kube-prometheus-stack"
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.defaultDashboardsEnabled=true \
  --wait

log "Applying the ArgoCD app-of-apps root application"
kubectl apply -f ../../kubernetes-helm/gitops/argocd/app-of-apps.yaml

log "Bootstrap complete. ArgoCD now owns application sync from Git — future changes should go through PRs, not helm upgrade."

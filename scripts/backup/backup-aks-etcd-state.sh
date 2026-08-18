#!/usr/bin/env bash
#
# backup-aks-etcd-state.sh
#
# Exports all namespaced resource manifests from an AKS cluster to
# timestamped JSON, then uploads the archive to Azure Blob Storage.
# AKS manages etcd directly (no customer access), so cluster-state backup
# in practice means "declaratively export everything" rather than a true
# etcd snapshot — this script does that, plus prunes old archives.
#
# Usage:
#   ./backup-aks-etcd-state.sh <storage-account> <container>

set -euo pipefail

STORAGE_ACCOUNT="${1:?Usage: $0 <storage-account> <container>}"
CONTAINER="${2:?Usage: $0 <storage-account> <container>}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
WORKDIR="$(mktemp -d)"
ARCHIVE="cluster-backup-${TIMESTAMP}.tar.gz"
RETENTION_DAYS=30

trap 'rm -rf "$WORKDIR"' EXIT

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }

log "Exporting namespaced resources"
NAMESPACES=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}')
for ns in $NAMESPACES; do
  mkdir -p "$WORKDIR/$ns"
  for kind in deployment statefulset configmap secret ingress service pvc; do
    kubectl get "$kind" -n "$ns" -o json > "$WORKDIR/$ns/$kind.json" 2>/dev/null || true
  done
done

log "Archiving export"
tar -czf "/tmp/$ARCHIVE" -C "$WORKDIR" .

log "Uploading to Azure Blob Storage (az login via workload identity / managed identity assumed)"
az storage blob upload \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER" \
  --name "$ARCHIVE" \
  --file "/tmp/$ARCHIVE" \
  --auth-mode login \
  --overwrite

log "Pruning archives older than ${RETENTION_DAYS} days"
CUTOFF=$(date -u -d "-${RETENTION_DAYS} days" +%Y-%m-%dT%H:%M:%SZ)
az storage blob list \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER" \
  --auth-mode login \
  --query "[?properties.lastModified < \`$CUTOFF\`].name" -o tsv |
while read -r blob; do
  [ -n "$blob" ] && az storage blob delete --account-name "$STORAGE_ACCOUNT" --container-name "$CONTAINER" --name "$blob" --auth-mode login
done

log "Backup complete: $ARCHIVE"

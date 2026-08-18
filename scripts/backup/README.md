# backup

`backup-aks-etcd-state.sh` — since AKS manages the control plane (etcd)
directly and doesn't expose it for snapshotting, "backing up cluster state"
means exporting every namespaced resource's manifest and archiving it to
Blob Storage on a schedule (cron / AKS CronJob), with automatic pruning
past a 30-day retention window.

This is a **disaster-recovery aid for reconstructing cluster state**, not a
substitute for GitOps — application state should already be reproducible
from the Git repo via ArgoCD. This script mainly protects against
imperative drift: anything created directly with `kubectl apply` outside
of Git.

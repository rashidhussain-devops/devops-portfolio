#!/usr/bin/env bash
#
# check_backup_status.sh
#
# Example Telegraf "exec" input script: checks a cloud storage container
# for a backup job's most recent successful upload and emits the age (in
# hours) as InfluxDB line protocol, so backup freshness becomes a normal
# Grafana panel and can alert like any other metric — instead of living
# only in a backup tool's own dashboard that nobody checks daily.
#
# Requires: az cli logged in with Storage Blob Data Reader on the target
# container.

set -euo pipefail

STORAGE_ACCOUNT="${BACKUP_STORAGE_ACCOUNT:-backupforveeam001}"
CONTAINER="${BACKUP_CONTAINER:-firewallbackup}"

latest_blob_time=$(az storage blob list \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER" \
  --auth-mode login \
  --query "max_by([], &properties.lastModified).properties.lastModified" \
  -o tsv 2>/dev/null || echo "")

if [ -z "$latest_blob_time" ]; then
  echo "backup_status,container=${CONTAINER} age_hours=999,status=\"unknown\""
  exit 0
fi

latest_epoch=$(date -d "$latest_blob_time" +%s)
now_epoch=$(date -u +%s)
age_hours=$(( (now_epoch - latest_epoch) / 3600 ))

status="ok"
[ "$age_hours" -gt 168 ] && status="stale"   # older than a week

echo "backup_status,container=${CONTAINER} age_hours=${age_hours}i,status=\"${status}\""

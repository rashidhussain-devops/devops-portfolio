#!/usr/bin/env bash
#
# create-azure-snapshot.sh — takes an incremental snapshot of every managed
# disk (OS + data disks) attached to each server in the inventory, before
# patching begins. Incremental snapshots only bill for changed blocks since
# the last snapshot, so running this weekly is cheap even at scale.
#
# Also tags each snapshot with a retention date and prunes anything past
# that date from a PRIOR run, so old pre-patch snapshots don't accumulate
# indefinitely.
#
# Usage: ./create-azure-snapshot.sh <inventory.json> <retention_days>

set -euo pipefail

INVENTORY_FILE="${1:?Usage: $0 <inventory.json> <retention_days>}"
RETENTION_DAYS="${2:?Usage: $0 <inventory.json> <retention_days>}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EXPIRY_DATE="$(date -u -d "+${RETENTION_DAYS} days" +%Y-%m-%d)"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }

jq -c '.[]' "$INVENTORY_FILE" | while read -r server; do
    name=$(echo "$server" | jq -r '.name')
    rg=$(echo "$server" | jq -r '.rg')

    log "Snapshotting disks for $name"

    disk_ids=$(az vm show --resource-group "$rg" --name "$name" \
        --query "[storageProfile.osDisk.managedDisk.id, storageProfile.dataDisks[].managedDisk.id]" \
        -o tsv | grep -v '^$')

    for disk_id in $disk_ids; do
        disk_name=$(basename "$disk_id")
        snapshot_name="${disk_name}-prepatch-${TIMESTAMP}"

        az snapshot create \
            --resource-group "$rg" \
            --name "$snapshot_name" \
            --source "$disk_id" \
            --incremental true \
            --tags "purpose=pre-patch" "expiry=${EXPIRY_DATE}" "server=${name}" \
            --output none

        echo "Created: $snapshot_name (expires ${EXPIRY_DATE})"
    done
done

log "Pruning expired pre-patch snapshots"
today="$(date -u +%Y-%m-%d)"
az snapshot list --query "[?tags.purpose=='pre-patch']" -o json |
    jq -c '.[]' |
    while read -r snap; do
        expiry=$(echo "$snap" | jq -r '.tags.expiry // empty')
        [[ -z "$expiry" ]] && continue
        if [[ "$expiry" < "$today" ]]; then
            snap_name=$(echo "$snap" | jq -r '.name')
            snap_rg=$(echo "$snap" | jq -r '.resourceGroup')
            echo "Deleting expired snapshot: $snap_name (expired $expiry)"
            az snapshot delete --resource-group "$snap_rg" --name "$snap_name"
        fi
    done

log "Snapshot stage complete"

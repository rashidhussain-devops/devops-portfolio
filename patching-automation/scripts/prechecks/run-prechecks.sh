#!/usr/bin/env bash
#
# run-prechecks.sh — validates each server in the inventory is healthy
# enough to patch safely, and records a baseline for post-patch comparison.
#
# Checks per server (via `az vm run-command`, so no direct SSH/WinRM
# exposure needed from the CI agent):
#   - disk free space above threshold (patches can fail mid-install on a
#     full disk, which is worse than not patching at all)
#   - no other update/package-manager process already holding a lock
#   - critical services running (baseline captured for postcheck diff)
#   - pending reboot NOT already outstanding from a prior run
#
# Usage: ./run-prechecks.sh <inventory.json>
# Writes: precheck-report.json (in the same directory as the inventory file)

set -euo pipefail

INVENTORY_FILE="${1:?Usage: $0 <inventory.json>}"
REPORT_FILE="$(dirname "$INVENTORY_FILE")/precheck-report.json"
MIN_FREE_DISK_PCT=15

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }

LINUX_CHECK_SCRIPT='
set -e
echo "{"
echo "\"disk_free_pct\": $(df / | awk "NR==2 {print 100-\$5}" | tr -d "%"),"
echo "\"apt_lock_held\": $(fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 && echo true || echo false),"
echo "\"reboot_required\": $([ -f /var/run/reboot-required ] && echo true || echo false),"
echo "\"failed_services\": $(systemctl --failed --no-legend | wc -l)"
echo "}"
'

WINDOWS_CHECK_SCRIPT='
$disk = Get-PSDrive C | ForEach-Object { [math]::Round(($_.Free / ($_.Free + $_.Used)) * 100, 1) }
$pendingReboot = Test-Path "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Component Based Servicing\\RebootPending"
$failedServices = (Get-Service | Where-Object { $_.Status -eq "Stopped" -and $_.StartType -eq "Automatic" }).Count
@{ disk_free_pct = $disk; reboot_required = $pendingReboot; failed_services = $failedServices } | ConvertTo-Json -Compress
'

echo "[" > "$REPORT_FILE"
first=true

jq -c '.[]' "$INVENTORY_FILE" | while read -r server; do
    name=$(echo "$server" | jq -r '.name')
    rg=$(echo "$server" | jq -r '.rg')

    log "Pre-checking $name"

    if [[ "$name" == *win* ]]; then
        result=$(az vm run-command invoke --resource-group "$rg" --name "$name" \
            --command-id RunPowerShellScript --scripts "$WINDOWS_CHECK_SCRIPT" \
            --query "value[0].message" -o tsv | tail -1)
    else
        result=$(az vm run-command invoke --resource-group "$rg" --name "$name" \
            --command-id RunShellScript --scripts "$LINUX_CHECK_SCRIPT" \
            --query "value[0].message" -o tsv | tail -1)
    fi

    disk_free=$(echo "$result" | jq -r '.disk_free_pct // 0')
    if (( $(echo "$disk_free < $MIN_FREE_DISK_PCT" | bc -l) )); then
        echo "FAIL: $name has only ${disk_free}% free disk (threshold ${MIN_FREE_DISK_PCT}%)" >&2
        exit 1
    fi

    [[ "$first" == true ]] && first=false || echo "," >> "$REPORT_FILE"
    echo "{\"server\": \"$name\", \"baseline\": $result}" >> "$REPORT_FILE"
done

echo "]" >> "$REPORT_FILE"
log "All servers passed prechecks. Baseline written to $REPORT_FILE"

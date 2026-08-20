#!/usr/bin/env bash
#
# run-postchecks.sh — re-runs the same health checks after patching and
# diffs against the precheck baseline. The goal isn't just "is it up" but
# "did patching regress anything that was previously healthy" — a server
# that comes back online with three newly-failed services is a rollback
# candidate even though it technically booted.
#
# Usage: ./run-postchecks.sh <inventory.json> <precheck-report.json>
# Exit code 1 if any server regressed; triggers the Notify stage either way
# so failures are still reported, not swallowed.

set -euo pipefail

INVENTORY_FILE="${1:?Usage: $0 <inventory.json> <precheck-report.json>}"
BASELINE_FILE="${2:?Usage: $0 <inventory.json> <precheck-report.json>}"
REGRESSIONS=0

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }

LINUX_CHECK_SCRIPT='
echo "{"
echo "\"disk_free_pct\": $(df / | awk "NR==2 {print 100-\$5}" | tr -d "%"),"
echo "\"reboot_required\": $([ -f /var/run/reboot-required ] && echo true || echo false),"
echo "\"failed_services\": $(systemctl --failed --no-legend | wc -l),"
echo "\"kernel\": \"$(uname -r)\""
echo "}"
'

WINDOWS_CHECK_SCRIPT='
$disk = Get-PSDrive C | ForEach-Object { [math]::Round(($_.Free / ($_.Free + $_.Used)) * 100, 1) }
$failedServices = (Get-Service | Where-Object { $_.Status -eq "Stopped" -and $_.StartType -eq "Automatic" }).Count
$hotfix = (Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1).HotFixID
@{ disk_free_pct = $disk; failed_services = $failedServices; latest_hotfix = $hotfix } | ConvertTo-Json -Compress
'

jq -c '.[]' "$INVENTORY_FILE" | while read -r server; do
    name=$(echo "$server" | jq -r '.name')
    rg=$(echo "$server" | jq -r '.rg')

    log "Post-checking $name"

    if [[ "$name" == *win* ]]; then
        result=$(az vm run-command invoke --resource-group "$rg" --name "$name" \
            --command-id RunPowerShellScript --scripts "$WINDOWS_CHECK_SCRIPT" \
            --query "value[0].message" -o tsv | tail -1)
    else
        result=$(az vm run-command invoke --resource-group "$rg" --name "$name" \
            --command-id RunShellScript --scripts "$LINUX_CHECK_SCRIPT" \
            --query "value[0].message" -o tsv | tail -1)
    fi

    baseline_failed=$(jq -r --arg n "$name" '.[] | select(.server==$n) | .baseline.failed_services // 0' "$BASELINE_FILE")
    current_failed=$(echo "$result" | jq -r '.failed_services // 0')

    if (( current_failed > baseline_failed )); then
        echo "REGRESSION: $name has $current_failed failed services (was $baseline_failed before patching)" >&2
        REGRESSIONS=$((REGRESSIONS + 1))
    else
        echo "OK: $name — $current_failed failed services (baseline $baseline_failed)"
    fi
done

if (( REGRESSIONS > 0 )); then
    log "$REGRESSIONS server(s) regressed post-patch — flagging for manual review"
    exit 1
fi

log "All servers passed postchecks with no regressions"

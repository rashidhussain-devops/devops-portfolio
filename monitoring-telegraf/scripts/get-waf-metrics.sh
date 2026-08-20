#!/usr/bin/env bash
#
# get-waf-metrics.sh
#
# Pulls WAF-relevant metrics (total requests, blocked requests, matched
# rules) for an Application Gateway from the Azure Monitor Metrics REST API
# and emits them as InfluxDB line protocol on stdout, for Telegraf's
# inputs.exec to consume. Authenticates via a service principal (client
# credentials flow) — no interactive `az login` in the agent's execution
# path.

set -euo pipefail

TENANT_ID="${AZURE_TENANT_ID:?}"
CLIENT_ID="${AZURE_CLIENT_ID:?}"
CLIENT_SECRET="${AZURE_CLIENT_SECRET:?}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:?}"
RESOURCE_GROUP="${WAF_RESOURCE_GROUP:?}"
APP_GATEWAY_NAME="${WAF_APP_GATEWAY_NAME:?}"

TOKEN=$(curl -s -X POST \
  "https://login.microsoftonline.com/${TENANT_ID}/oauth2/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "resource=https://management.azure.com/" \
  | jq -r '.access_token')

RESOURCE_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Network/applicationGateways/${APP_GATEWAY_NAME}"

METRICS=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
  "https://management.azure.com${RESOURCE_ID}/providers/Microsoft.Insights/metrics?api-version=2018-01-01&metricnames=TotalRequests,BlockedCount,BlockedReqCount&timespan=PT5M&interval=PT1M&aggregation=Total")

echo "$METRICS" | jq -r --arg host "$APP_GATEWAY_NAME" '
  .value[] |
  .name.value as $metric |
  .timeseries[]?.data[]? |
  select(.total != null) |
  "azure_waf,host=\($host),metric=\($metric) value=\(.total)"
'

# Hybrid Monitoring — Azure + On-Prem via Telegraf, InfluxDB, and Grafana

A monitoring stack for environments where workloads span Azure and on-prem
infrastructure that Azure Monitor can't reach directly. One Telegraf agent
design (or SNMP poll, for devices that can't run an agent) feeds one
InfluxDB instance, so Grafana gives a single pane of glass instead of
switching between Azure Monitor and a separate on-prem tool.

## What's monitored

| Target | Method | Config |
|---|---|---|
| Azure — Sophos XG Firewall (cloud) | SNMP | `roles/sophos-cloud-firewall.conf` |
| Azure — Application Gateway WAF | Azure Monitor REST API via `inputs.exec` | `roles/azure-waf.conf` + `scripts/get-waf-metrics.sh` |
| On-prem — Domain Controllers | `win_perf_counters` (NTDS, Netlogon, DFSR) | `roles/domain-controller.conf` |
| On-prem — Barracuda CloudGen Firewall | SNMP | `roles/barracuda-onprem-firewall.conf` |
| On-prem — file/storage server | `disk`/`diskio` + `win_perf_counters` | `roles/storage-server.conf` |
| On-prem — DHCP Server | `win_perf_counters` (scope exhaustion signals) | `roles/dhcp-server.conf` |
| On-prem — Veeam Backup & Replication | Veeam PowerShell module via `inputs.exec` | `roles/veeam-backup.conf` + `scripts/check-veeam-jobs.ps1` |

Each host also runs the base OS-level config (`telegraf-windows.conf` or
`telegraf-linux.conf` — CPU/mem/disk/net) layered with its role-specific
file via Telegraf's `--config-directory` flag, so a DC, for example, runs
`telegraf-windows.conf` + `roles/domain-controller.conf` together rather
than duplicating the base counters in every role file.

This is a companion to the Prometheus/Grafana stack in
[`../scripts/aks-bootstrap`](../scripts/aks-bootstrap) — that one monitors
the Kubernetes cluster itself (cloud-native, pull-based, ephemeral targets);
this one monitors traditional long-lived infrastructure (VMs, appliances,
physical or virtual servers) where a push-based agent model fits better and
where a lot of the target estate predates or sits outside Kubernetes
entirely.

## Why Telegraf/InfluxDB instead of Azure Monitor Agent everywhere

Azure Monitor Agent doesn't run on network appliances (firewalls) or
non-Azure on-prem hosts. Telegraf does — as an agent on any Windows/Linux
host, or via SNMP polling for anything that only exposes SNMP, or via
`inputs.exec` for anything with neither (Veeam, WAF metrics behind an API).
Consolidating Azure and on-prem infrastructure into one Telegraf/InfluxDB
pipeline avoids maintaining two separate monitoring stacks with two
separate alerting configs.

## Why bare-metal/VM instead of containerized in production

`docker-compose.yml` here is for quickly testing dashboard or datasource
changes locally. The real deployment ran directly on an Ubuntu 24.04 host —
mainly because SNMP polling and Windows agents both benefit from direct
host networking, and because this stack's uptime requirements didn't
justify containerizing a two-service, rarely-updated pipeline.

## Structure

```
monitoring-telegraf/
├── telegraf-configs/
│   ├── telegraf-linux.conf              # Base Linux: cpu/mem/disk/net
│   ├── telegraf-windows.conf            # Base Windows: win_perf_counters
│   ├── telegraf-snmp-network.conf       # Generic SNMP template
│   └── roles/                           # One file per specific target type
│       ├── sophos-cloud-firewall.conf
│       ├── azure-waf.conf
│       ├── domain-controller.conf
│       ├── barracuda-onprem-firewall.conf
│       ├── storage-server.conf
│       ├── dhcp-server.conf
│       └── veeam-backup.conf
├── scripts/
│   ├── check_backup_status.sh           # Generic blob-storage backup-age check
│   ├── get-waf-metrics.sh               # Azure Monitor REST API → line protocol
│   └── check-veeam-jobs.ps1             # Veeam PowerShell → line protocol
├── grafana-provisioning/
│   ├── datasources/influxdb.yml         # Auto-registers the InfluxDB datasource
│   └── dashboards/                      # Auto-loaded dashboard JSON
└── docker-compose.yml                   # Local stack for dashboard development
```

## A real fix worth documenting: the win_perf_counters Memory quirk

Telegraf's `win_perf_counters` plugin silently returns no data for certain
single-instance Windows performance counters (Memory, NTDS, DHCP Server are
all affected) unless `Instances` is explicitly set to `["------"]` rather
than `["*"]` or left empty. This is undocumented behavior that costs real
debugging time — worth calling out here since every role config above that
touches a single-instance counter object relies on this fix.

## Custom exec inputs: metrics for things with no stock plugin

Not everything worth monitoring has a Telegraf input plugin — "is the last
Veeam job less than a day old" or "how many requests did the WAF block in
the last 5 minutes" are business-logic checks against an API or a
vendor-specific PowerShell module, not a system metric. The pattern is the
same both times: a small script queries the actual source of truth and
emits InfluxDB line protocol, wired up via `inputs.exec`. This turns any
scriptable check into a normal Grafana panel with normal alerting, instead
of a separate manual process nobody remembers to check.


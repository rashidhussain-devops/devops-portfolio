# DevOps / Platform Engineering Portfolio

Reusable Terraform modules, a production-leaning Helm chart, GitOps
manifests, GitHub Actions pipelines, and operational automation scripts —
built to demonstrate how I design and run cloud infrastructure, not just
that I can write YAML.

**Rashid Hussain** — Cloud Architect / Senior DevOps Engineer · Azure, AKS/EKS, Terraform, GitOps
[LinkedIn](#) · [Certifications: AZ-400, Terraform Associate](#)

## Flagship: designing a CI/CD platform from zero

Most of what's below is reusable IaC and pipeline patterns. This one is
the actual project that made the rest necessary:

QRCS's official website and CRM application were both deployed by a
developer RDP-ing into a Windows Server and manually copying files into
`inetpub\wwwroot`. As traffic grew, the servers came under increasing load
with no way to scale short of provisioning another VM by hand — and every
release carried real outage risk. I recommended and built the replacement
myself: an Azure DevOps CI/CD pipeline running on an on-premises
self-hosted build agent, deploying containerized applications to AKS with
zero-downtime rolling updates. Developers now push to a branch and the
pipeline handles build, image push, and deployment — no RDP, no outage
window, no manual VM provisioning to scale.

**[→ Full case study, architecture diagrams, and the actual pipeline/agent/Kubernetes configs](./legacy-to-aks-migration)**

## What's here and why

| Path | What it shows |
|---|---|
| [`legacy-to-aks-migration/`](./legacy-to-aks-migration) | The flagship project above — the real migration, in detail |
| [`terraform-modules/`](./terraform-modules) | Composable, versioned IaC — networking, AKS, storage — with real defaults (Workload Identity, private endpoints, disabled shared keys), not toy examples |
| [`kubernetes-helm/`](./kubernetes-helm) | A hardened application Helm chart plus an ArgoCD app-of-apps GitOps layout |
| [`.github/workflows/`](./.github/workflows) | CI/CD: Terraform plan/apply with OIDC (no stored cloud secrets), container build/scan/sign, Helm lint, scheduled drift detection |
| [`scripts/`](./scripts) | Operational automation: Entra ID deprovisioning, AKS cluster bootstrap, cluster-state backup, cross-platform patching with pre/post checks and snapshotting |
| [`patching-automation/`](./patching-automation) | Scheduled Windows/Linux patch pipeline — implemented in both Azure DevOps and Jenkins/Bitbucket, with prechecks, pre-patch snapshots, postcheck regression detection, and SendGrid notifications via Azure Logic App |
| [`monitoring-telegraf/`](./monitoring-telegraf) | Grafana + InfluxDB + Telegraf stack monitoring Azure (Sophos cloud firewall, Application Gateway WAF) and on-prem (Domain Controllers, Barracuda firewall, storage server, DHCP, Veeam backup) side by side |
| [`docs/architecture.md`](./docs/architecture.md) | How the pieces fit together end to end |

## Design principles behind this repo

- **Identity over secrets.** GitHub Actions authenticates to Azure via OIDC
  federated credentials, not a stored client secret. AKS workloads
  authenticate via Workload Identity. The deprovisioning runbook runs under
  a Managed Identity. No long-lived cloud credentials anywhere in this repo.
- **GitOps as the deployment boundary.** Terraform stops at the cluster
  boundary; ArgoCD owns everything inside it via the app-of-apps pattern.
  A new service is a PR that adds one YAML file, not a manual `helm install`
  from someone's laptop.
- **Everything that can be checked, is checked in CI**: `terraform fmt`,
  `terraform validate`, `tflint`, `checkov`, `helm lint`, `kubeconform`,
  `kube-linter`, and a container image vulnerability scan (Trivy) with
  keyless image signing (cosign) before anything ships.
- **Modules document their own trade-offs.** Every module and script has a
  README explaining *why* a default was chosen, not just what it does —
  see e.g. [`azure-aks-cluster/README.md`](./terraform-modules/azure-aks-cluster/README.md#why-these-defaults).

## Repository structure

```
devops-portfolio/
├── terraform-modules/
│   ├── azure-networking/        # VNet, subnets, per-subnet NSGs
│   ├── azure-aks-cluster/       # AKS: Workload Identity, Cilium, Defender
│   └── azure-storage-account/   # Hardened storage: no shared keys, private endpoint
├── kubernetes-helm/
│   ├── charts/sample-webapp/    # Hardened application chart (HPA, PDB, non-root)
│   └── gitops/argocd/           # App-of-apps root + child Application manifests
├── legacy-to-aks-migration/
│   ├── docker/                  # Containerizing an existing IIS site (no framework rewrite)
│   ├── kubernetes/              # Rolling-update deployment: the actual zero-downtime mechanism
│   ├── azure-devops/            # Build → push → deploy pipeline, on-prem self-hosted agent
│   ├── self-hosted-agent/       # Registering an on-prem Windows host as a build agent
│   └── docs/architecture.md     # Before/after diagrams and the reasoning
├── .github/workflows/
│   ├── terraform-ci.yml         # fmt/validate/tflint/checkov + OIDC plan on PRs
│   ├── docker-build-push.yml    # Multi-arch build, Trivy scan, cosign sign
│   ├── helm-lint.yml            # helm lint + kubeconform + kube-linter
│   └── scheduled-drift-check.yml
├── scripts/
│   ├── azure-ad-deprovisioning/ # Entra ID leaver automation (Managed Identity)
│   ├── aks-bootstrap/           # One-time cluster bootstrap (ingress, cert-manager, ArgoCD)
│   └── backup/                  # Namespaced resource export + Blob Storage archive
├── patching-automation/
│   ├── azure-devops/            # azure-pipelines.yml: precheck → snapshot → patch → postcheck → notify
│   ├── jenkins/                 # Equivalent Jenkinsfile, Bitbucket-sourced
│   ├── scripts/                 # Pre/postcheck + Azure snapshot scripts shared by both pipelines
│   └── logic-app/               # ARM template: Logic App + SendGrid notification
├── monitoring-telegraf/
│   ├── telegraf-configs/         # Base Linux/Windows configs + SNMP template
│   │   └── roles/                # Sophos FW, Azure WAF, DCs, Barracuda FW, storage, DHCP, Veeam
│   ├── scripts/                  # WAF metrics + Veeam job status → InfluxDB line protocol
│   ├── grafana-provisioning/     # Provisioned datasource + dashboards
│   └── docker-compose.yml        # InfluxDB + Grafana + local Telegraf
└── docs/
    └── architecture.md
```

## Quickstart

```bash
# Validate a Terraform module in isolation
cd terraform-modules/azure-aks-cluster && terraform init -backend=false && terraform validate

# Lint and render the Helm chart
helm lint kubernetes-helm/charts/sample-webapp
helm template kubernetes-helm/charts/sample-webapp | less

# Provision networking + AKS, then bootstrap the cluster
cd envs/dev && terraform apply
./scripts/aks-bootstrap/bootstrap-cluster.sh <cluster-name> <resource-group>
```

`envs/<env>/` root modules (composing the three Terraform modules per
environment) are intentionally not included in this public repo since they'd
contain environment-specific state backend config — the module usage
examples in each module's README show the composition pattern.

## Background

6+ years across Azure, Kubernetes (AKS/EKS), Terraform, and GitOps
(ArgoCD/FluxCD), most recently building out cloud landing-zone and platform
automation at Qatar Red Crescent Society. This repo is a from-scratch,
sanitized rebuild of the patterns used in that work, for public reference.

## License

MIT — see [LICENSE](./LICENSE). Use freely; issues and PRs welcome.

# On-Premises Self-Hosted Azure DevOps Agent

`register-agent.ps1` installs and registers the Azure Pipelines agent as a
Windows service on an on-prem host, joining it to a named agent pool that
the pipeline (`../azure-devops/azure-pipelines-website.yml`) targets via
`pool: name: OnPrem-Windows-Agents`.

## Why self-hosted instead of Microsoft-hosted agents

- **Windows container builds.** Microsoft-hosted Windows agents exist, but
  building and pushing Windows container images reliably needs more control
  over the host (base image caching, disk space for layers) than the
  hosted pool's per-job clean environment gives you economically at
  QRCS's build frequency.
- **Idle hardware.** The physical/virtual host that used to run the
  IIS site directly was sitting mostly idle once the site itself moved
  into AKS — repurposing it as a build agent turned a soon-to-be-decommissioned
  box into useful infrastructure instead of standing up new Azure DevOps
  parallel job spend.
- **Network locality.** The agent sits on the same network as the ACR and
  AKS cluster it deploys to, so image pushes and `kubectl` operations don't
  round-trip through the public internet.

## Operational notes

- The agent runs as a Windows service (`--runAsService`), so it survives
  reboots and doesn't depend on an interactive login session.
- The PAT used to register the agent only needs Agent Pools (read, manage)
  scope — deliberately not a broad admin token — and is generated once,
  stored in Key Vault, and never committed to source control.
- Scaling out is copy-paste: run the same script against another on-prem
  host with the same pool name, and Azure DevOps load-balances jobs across
  every agent registered to that pool automatically.

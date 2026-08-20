# Legacy IIS/SharePoint → Azure DevOps CI/CD on AKS

A real migration story: moving a corporate website and CRM application off
manual, RDP-based deployments on Windows Server and onto an automated,
zero-downtime CI/CD pipeline running on Kubernetes.

## The problem

The organization's official website (IIS) and CRM application (Windows
Server + SharePoint) were both deployed the same way: a developer would
RDP into the production server and manually copy updated files into place.
As traffic grew, the servers came under increasing load with no way to
scale out short of manually provisioning another VM — and every deployment
carried real outage risk, since there was no way to guarantee a clean
cutover between old and new files.

## What I recommended and built

Rather than just adding more VMs behind a load balancer (which would have
addressed capacity but left the manual, risky deployment process
untouched), I recommended migrating both applications to containers running
on AKS, with an Azure DevOps pipeline handling build and deployment
end-to-end — including an **on-premises self-hosted build agent**, so
Windows container builds didn't need new Azure DevOps parallel-job spend
and could reuse hardware that was otherwise sitting idle post-migration.

## What's in this folder

| Path | What it shows |
|---|---|
| [`docker/Dockerfile.website`](./docker/Dockerfile.website) | Containerizing an existing IIS site without a framework rewrite |
| [`kubernetes/website-deployment.yaml`](./kubernetes/website-deployment.yaml) | Rolling update config (`maxUnavailable: 0`) that's the actual mechanism behind "zero downtime" |
| [`azure-devops/azure-pipelines-website.yml`](./azure-devops/azure-pipelines-website.yml) | Build → push → deploy pipeline, gated by a manual approval on the production environment |
| [`self-hosted-agent/`](./self-hosted-agent) | Registering an on-prem Windows host as a self-hosted Azure DevOps build agent, and why |
| [`gitops/`](./gitops) | ArgoCD + FluxCD taking over sync from the pipeline, plus per-application aliases for day-to-day operation |
| [`docs/architecture.md`](./docs/architecture.md) | Before/after diagrams and the reasoning behind each decision |

## Outcome

Developers now push code to a branch and the pipeline handles the rest —
build, image push, and a git-driven deployment that ArgoCD/FluxCD
continuously reconcile against the cluster, only retiring an old pod once
its replacement is confirmed healthy. No more manual RDP deployments, no
more outage window during releases, no more drift between what's running
and what git says should be running, and horizontal scaling is now a
replica-count change instead of a new VM to provision by hand.

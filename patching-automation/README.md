# Windows/Linux Patching Automation

Scheduled patch-management pipeline for a mixed Windows/Linux Azure fleet,
implemented twice — once as an Azure DevOps YAML pipeline, once as a
Jenkinsfile sourced from Bitbucket — to demonstrate the same operational
pattern across both toolchains.

## Why two implementations

Organizations rarely get to pick their CI/CD tooling from a blank slate;
they inherit whatever's already standardized. Having both an Azure DevOps
and a Jenkins/Bitbucket version of the same pipeline shows the pattern
translates across tooling, not just familiarity with one platform.

## Pipeline flow (both implementations)

```
Precheck → Snapshot → Patch → Postcheck → Notify (always runs, even on failure)
```

1. **Precheck** (`scripts/prechecks/run-prechecks.sh`) — pulls the target
   server group from Azure tags, then remotely checks disk space, package-
   manager lock state, pending-reboot flags, and currently-failed services
   on each server via `az vm run-command` (no direct SSH/WinRM exposure
   from the CI agent). Any server under the free-disk threshold fails the
   whole run before anything is touched. The results are also saved as a
   **baseline** for the postcheck comparison.

2. **Snapshot** (`scripts/snapshot/create-azure-snapshot.sh`) — takes an
   incremental snapshot of every managed disk (OS + data) per server,
   tagged with an expiry date, and prunes snapshots past their retention
   window from prior runs. Incremental snapshots only bill for changed
   blocks, so this is cheap to run weekly indefinitely.

3. **Patch** — Linux via `apt-get upgrade` over `az vm run-command`;
   Windows via the `PSWindowsUpdate` module, same mechanism. Skipped
   entirely if the pipeline is run with `dryRun: true` — useful for
   validating prechecks/snapshots without touching production.

4. **Postcheck** (`scripts/postchecks/run-postchecks.sh`) — re-runs the
   same health checks and **diffs against the precheck baseline**, not
   just an absolute pass/fail. A server with 3 new failed services after
   patching is a regression even if it technically came back online.

5. **Notify** — always runs (`condition: always()` / `post { always {} }`),
   regardless of whether earlier stages succeeded, and posts a JSON
   payload to an Azure Logic App webhook, which sends the actual email via
   SendGrid — see [`../logic-app/patch-notification-logicapp.json`](../logic-app/patch-notification-logicapp.json).

## Why the Logic App sits between the pipeline and SendGrid

The pipeline doesn't hold a SendGrid API key at all — it only knows one
webhook URL. The Logic App owns the SendGrid connection and the email
template. That means the notification format can be changed (add a Teams
channel post, change the recipient list per target group, add retry logic)
without touching pipeline code or re-deploying anything CI-side.

## Credentials

Every implementation authenticates to Azure via a service principal /
service connection scoped to just the `az vm run-command` and snapshot
permissions needed — never a broad Owner/Contributor grant on the
subscription. Jenkins credentials (Bitbucket app password, Azure SP,
SendGrid key) live in the Jenkins Credentials Store; Azure DevOps
equivalents live in a variable group backed by Key Vault. Nothing secret
is in this repo.

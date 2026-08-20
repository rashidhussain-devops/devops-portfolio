<#
.SYNOPSIS
    Installs and registers an Azure DevOps self-hosted build agent as a
    Windows service, on-premises.

.DESCRIPTION
    Microsoft-hosted parallel jobs don't support Windows container builds
    without extra cost tiers, and the on-prem hardware previously running
    the manually-deployed IIS site was sitting mostly idle after the
    migration — repurposing it as a build agent avoided both the extra
    Azure DevOps spend and standing up new infrastructure just to build
    Docker images.

.NOTES
    Run as Administrator on the on-prem host designated as a build agent.
    Requires a Personal Access Token with Agent Pools (read, manage) scope,
    generated once and stored in the organization's Azure Key Vault — not
    hardcoded here.
#>

param(
    [Parameter(Mandatory)]
    [string]$OrgUrl,             # e.g. https://dev.azure.com/qrcs

    [Parameter(Mandatory)]
    [string]$PoolName,           # e.g. OnPrem-Windows-Agents

    [Parameter(Mandatory)]
    [string]$PAT,

    [string]$AgentInstallPath = "C:\azagent",
    [string]$AgentVersion = "3.232.1"
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Path $AgentInstallPath -Force | Out-Null
Set-Location $AgentInstallPath

Write-Output "Downloading Azure Pipelines agent v$AgentVersion..."
$agentZip = "vsts-agent-win-x64-$AgentVersion.zip"
Invoke-WebRequest `
    -Uri "https://vstsagentpackage.azureedge.net/agent/$AgentVersion/$agentZip" `
    -OutFile $agentZip

Expand-Archive -Path $agentZip -DestinationPath $AgentInstallPath -Force
Remove-Item $agentZip

Write-Output "Configuring agent against pool '$PoolName'..."
.\config.cmd `
    --unattended `
    --url $OrgUrl `
    --auth pat `
    --token $PAT `
    --pool $PoolName `
    --agent $env:COMPUTERNAME `
    --runAsService `
    --windowsLogonAccount "NT AUTHORITY\NetworkService"

Write-Output "Agent registered and running as a Windows service."
Write-Output "Verify status: Get-Service vstsagent.*"

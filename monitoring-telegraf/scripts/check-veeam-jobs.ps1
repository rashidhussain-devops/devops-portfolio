<#
.SYNOPSIS
    Reports Veeam B&R job status and last-success age as InfluxDB line
    protocol, for Telegraf's inputs.exec to consume.

.DESCRIPTION
    Runs locally on the Veeam server (requires the Veeam PowerShell
    snap-in/module to be present). For each backup job, emits:
      - result: 0 = Success, 1 = Warning, 2 = Failed (numeric so Grafana
        can threshold/color it directly)
      - hours_since_last_success: the metric that should actually page
        someone — a job silently failing for days is worse than one
        failure that self-corrects on the next run.
#>

Add-PSSnapin VeeamPSSnapIn -ErrorAction SilentlyContinue
Import-Module Veeam.Backup.PowerShell -ErrorAction SilentlyContinue

$jobs = Get-VBRJob

foreach ($job in $jobs) {
    $lastSession = $job.FindLastSession()
    $jobName = $job.Name -replace '\s', '_'

    $resultCode = switch ($lastSession.Result) {
        "Success" { 0 }
        "Warning" { 1 }
        "Failed"  { 2 }
        default   { 3 }
    }

    $lastSuccess = $job.GetLastResult()
    $hoursSinceSuccess = if ($lastSession.EndTime) {
        [math]::Round(((Get-Date) - $lastSession.EndTime).TotalHours, 1)
    } else {
        -1
    }

    Write-Output "veeam_backup,job=$jobName result=$resultCode,hours_since_last_run=$hoursSinceSuccess"
}

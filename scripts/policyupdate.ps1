param (
    [string]$systemPurpose,
    [string]$systemOwnership
)

. (Join-Path $PSScriptRoot "_common.ps1")

<#
.SYNOPSIS
    Installs the periodic-and-at-logon policy auto-update mechanism.

.DESCRIPTION
    Persists deployment state, deploys the auto-updater payload to a stable
    location outside C:\Windows\deploy, and registers a Scheduled Task that
    re-applies the policy + AppLocker layers whenever the configured GitHub
    branch advances.

    Persistent files (under C:\ProgramData\ZuidWest\policy-update\):
      - state.json        Deployment context, repo coordinates, last SHA
      - update.ps1        Copy of scripts/lib/policy-auto-updater.ps1
      - staging/          Created/destroyed per run (download workspace)

    Scheduled Task: \ZuidWest\PolicyAutoUpdate
      - Runs as SYSTEM at: system startup, any user logon, hourly
      - Only ever consults the GitHub API; downloads only when SHA changed

    Re-running this script (via install.ps1 -OnlyRun policyupdate) refreshes
    state.json with the current purpose/ownership and reinstalls the payload
    + task definition. The previously applied SHA is preserved so the next
    auto-update tick is still a no-op if nothing in main has moved.

.PARAMETER systemPurpose
    The purpose of the system: "radio", "tv", "editorial", or "plain".

.PARAMETER systemOwnership
    The ownership type: "shared", "personal", or "dedicated".
#>

if (-not $systemPurpose -or -not $systemOwnership) {
    throw "Both 'systemPurpose' and 'systemOwnership' parameters must be provided."
}

$persistentRoot = Join-Path $env:ProgramData "ZuidWest\policy-update"
$statePath = Join-Path $persistentRoot "state.json"
$updaterPath = Join-Path $persistentRoot "update.ps1"
$payloadSource = Join-Path $PSScriptRoot "lib\policy-auto-updater.ps1"
$taskFolder = "\ZuidWest"
$taskName = "PolicyAutoUpdate"
$taskFullPath = "$taskFolder\$taskName"

Write-Output "=== Policy Auto-Update Installation ==="
Write-Output ""

if (-not (Test-Path $payloadSource)) {
    throw "Auto-updater payload not found at $payloadSource"
}

if (-not (Test-Path $persistentRoot)) {
    New-Item -Path $persistentRoot -ItemType Directory -Force | Out-Null
}

# Build the new state. Preserve the previously applied SHA across re-runs so a
# fresh -OnlyRun policyupdate does not force a redundant policy reapply on the
# next tick.
$state = [ordered]@{
    schemaVersion    = 1
    repoOwner        = "oszuidwest"
    repoName         = "windows11-baseline"
    branch           = "main"
    systemPurpose    = $systemPurpose.ToLower()
    systemOwnership  = $systemOwnership.ToLower()
    scriptsToReapply = @("policies", "applocker")
    lastAppliedSha   = $null
    lastAppliedAt    = $null
    lastCheckAt      = $null
}

if (Test-Path $statePath) {
    try {
        $previous = Get-Content -Path $statePath -Raw | ConvertFrom-Json
        foreach ($key in @("lastAppliedSha", "lastAppliedAt", "lastCheckAt")) {
            if ($previous.PSObject.Properties.Name -contains $key) {
                $state[$key] = $previous.$key
            }
        }
    }
    catch {
        Write-Warning "Could not read existing state file ($_); starting fresh."
    }
}

$state | ConvertTo-Json -Depth 4 | Set-Content -Path $statePath -Encoding UTF8
Write-Output "Deployment state: $statePath"
Write-Output "  Purpose:    $($state.systemPurpose)"
Write-Output "  Ownership:  $($state.systemOwnership)"
Write-Output "  Repo:       $($state.repoOwner)/$($state.repoName)@$($state.branch)"
Write-Output "  Re-apply:   $($state.scriptsToReapply -join ', ')"

Copy-Item -Path $payloadSource -Destination $updaterPath -Force
Write-Output "Updater payload: $updaterPath"

# Register / refresh the Scheduled Task.
$action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$updaterPath`""

$startupTrigger = New-ScheduledTaskTrigger -AtStartup
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn

# Hourly: a -Once trigger anchored shortly after install, repeating every hour
# for a far-future duration. Avoids the "midnight daily + sub-day repetition"
# combo whose behaviour varies across Windows builds.
$hourlyTrigger = New-ScheduledTaskTrigger `
    -Once -At (Get-Date).AddMinutes(5) `
    -RepetitionInterval (New-TimeSpan -Hours 1) `
    -RepetitionDuration (New-TimeSpan -Days 365000)

$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

$task = New-ScheduledTask `
    -Action $action `
    -Trigger @($startupTrigger, $logonTrigger, $hourlyTrigger) `
    -Principal $principal `
    -Settings $settings `
    -Description "Streekomroep ZuidWest baseline policy auto-update. Polls GitHub for new commits on the configured branch and re-applies the policies + AppLocker layer when the SHA changes."

Register-ScheduledTask -TaskName $taskName -TaskPath $taskFolder -InputObject $task -Force | Out-Null
Write-Output "Scheduled Task registered: $taskFullPath"

Write-Output ""
Write-Output "Triggers: system startup, any user logon, hourly."
Write-Output "Logs:     $(Join-Path $env:ProgramData 'ZuidWest\Logs\policy-auto-update.log')"
Write-Output ""
Write-Output "=== Policy Auto-Update Installation complete ==="

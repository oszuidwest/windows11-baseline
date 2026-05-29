param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$installedSha,
    [bool]$seedInstalledSha
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_common.ps1")

<#
.SYNOPSIS
    Installs the periodic-and-at-logon policy auto-update mechanism.

.DESCRIPTION
    Persists deployment state, deploys the auto-updater payload to a stable
    runtime location under C:\ProgramData\ZuidWest, and registers a Scheduled
    Task that re-applies the policy + AppLocker layers whenever the configured
    GitHub branch advances.

    Persistent files (under C:\ProgramData\ZuidWest\policy-update\):
      - state.json        Deployment context, repo coordinates, last SHA
      - state.json.bak    Previous generation, kept by Save-DeploymentStateAtomic
      - update.ps1        Copy of scripts/lib/policy-auto-updater.ps1
      - staging/          Created/destroyed per run (download workspace)

    Scheduled Task: \ZuidWest\PolicyAutoUpdate
      - Runs as SYSTEM at: system startup, any user logon, hourly
      - Every trigger (startup, logon, hourly) carries -RandomDelay so the
        fleet does not poll in lockstep after a maintenance reboot, a
        morning logon rush, or on the hour. Windows are 15 min, 5 min, and
        60 min respectively.
      - The updater asks github.com's commits.atom feed (not api.github.com)
        for the current branch HEAD SHA, so the check does not consume the
        unauthenticated REST API budget at all.

    Re-running this script (via install.ps1 -OnlyRun policyupdate) refreshes
    state.json with the current purpose/ownership and reinstalls the payload
    + task definition. If any context field (purpose, ownership, repo, branch,
    scriptsToReapply) actually changed, the recorded lastAppliedSha and
    lastSelfUpdateSha are cleared so the next auto-update tick re-applies
    against the new context even when main has not moved.

    Full installs pass the exact commit SHA that install.ps1 downloaded and
    applied. In that case the state is seeded with that SHA to avoid a redundant
    first scheduled-task apply. -OnlyRun policyupdate does not seed unless the
    installer also ran policies and applocker in the same invocation.

.PARAMETER systemPurpose
    The purpose of the system: "radio", "tv", "editorial", or "plain".

.PARAMETER systemOwnership
    The ownership type: "shared", "personal", or "dedicated".
#>

if (-not $systemPurpose -or -not $systemOwnership) {
    throw "Both 'systemPurpose' and 'systemOwnership' parameters must be provided."
}

$persistentRoot = Join-ZuidWestPath "policy-update"
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
    schemaVersion     = 5
    enabled           = $true
    repoOwner         = "oszuidwest"
    repoName          = "windows11-baseline"
    branch            = "main"
    systemPurpose     = $systemPurpose.ToLower()
    systemOwnership   = $systemOwnership.ToLower()
    scriptsToReapply  = @("policies", "applocker")
    lastAppliedSha    = $null
    lastAppliedAt     = $null
    lastSelfUpdateSha = $null
    lastCheckAt       = $null
    backoffUntil      = $null
}

$previous = $null
if (Test-Path $statePath) {
    try {
        $previous = Read-DeploymentState -Path $statePath
    }
    catch {
        Write-Warning "Could not read existing state file ($_); starting fresh."
    }
}

if ($previous) {
    foreach ($key in @("enabled", "lastAppliedSha", "lastAppliedAt", "lastSelfUpdateSha", "lastCheckAt", "backoffUntil")) {
        if ($previous.PSObject.Properties.Name -contains $key -and $null -ne $previous.$key) {
            $state[$key] = $previous.$key
        }
    }
}

# Detect a context change: if any of the inputs that drive what gets applied
# changed since the previous deployment, null out the applied-SHA tracking so
# the next auto-update tick reapplies against the new context. Without this,
# an operator running -OnlyRun policyupdate to switch purpose/ownership would
# update state.json but the updater would short-circuit until main advances.
$contextChanged = $false
if ($previous) {
    $contextKeys = @('systemPurpose', 'systemOwnership', 'branch', 'repoOwner', 'repoName', 'scriptsToReapply')
    foreach ($key in $contextKeys) {
        $oldValue = $previous.$key
        $newValue = $state[$key]
        if ($oldValue -is [array] -or $newValue -is [array]) {
            $same = $null -eq (Compare-Object @($oldValue) @($newValue))
        }
        else {
            $same = ($oldValue -eq $newValue)
        }
        if (-not $same) {
            $contextChanged = $true
            break
        }
    }
}

if ($contextChanged) {
    $state.lastAppliedSha = $null
    $state.lastAppliedAt = $null
    $state.lastSelfUpdateSha = $null
    $state.backoffUntil = $null
    Write-Output "Deployment context changed since previous install; cleared applied-SHA tracking. Next auto-update tick will reapply."
}

if ($seedInstalledSha) {
    if (-not $installedSha -or $installedSha -notmatch '^[a-fA-F0-9]{40}$') {
        throw "Cannot seed policy auto-update state: installedSha must be a 40-character commit SHA."
    }

    $seedSha = $installedSha.ToLower()
    $state.lastAppliedSha = $seedSha
    $state.lastAppliedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $state.lastSelfUpdateSha = $seedSha
    Write-Output "Seeded applied SHA from installer download: $seedSha"
}

Save-DeploymentStateAtomic -Path $statePath -State $state
Write-Output "Deployment state: $statePath"
Write-Output "  Enabled:    $($state.enabled)"
Write-Output "  Purpose:    $($state.systemPurpose)"
Write-Output "  Ownership:  $($state.systemOwnership)"
Write-Output "  Repo:       $($state.repoOwner)/$($state.repoName)@$($state.branch)"
Write-Output "  Re-apply:   $($state.scriptsToReapply -join ', ')"

Copy-Item -Path $payloadSource -Destination $updaterPath -Force -ErrorAction Stop
Write-Output "Updater payload: $updaterPath"

# Register / refresh the Scheduled Task.
$action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$updaterPath`""

# Every trigger jitters with -RandomDelay so the fleet does not poll in
# lockstep. Without this, a post-maintenance reboot fleet-wide or a 09:00
# logon rush would land all checks on github.com within the same minute.
$startupTrigger = New-ScheduledTaskTrigger -AtStartup `
    -RandomDelay (New-TimeSpan -Minutes 15)

$logonTrigger = New-ScheduledTaskTrigger -AtLogOn `
    -RandomDelay (New-TimeSpan -Minutes 5)

$hourlyTrigger = New-ScheduledTaskTrigger `
    -Once -At (Get-Date).AddMinutes(5) `
    -RandomDelay (New-TimeSpan -Minutes 60) `
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
    -Description "Streekomroep ZuidWest baseline policy auto-update. Polls github.com's commits.atom feed (not the REST API) for new commits on the configured branch and re-applies the policies + AppLocker layer when the SHA changes."

Register-ScheduledTask -TaskName $taskName -TaskPath $taskFolder -InputObject $task -Force -ErrorAction Stop | Out-Null
Write-Output "Scheduled Task registered: $taskFullPath"

Write-Output ""
Write-Output "Triggers: startup (jitter 15 min), logon (jitter 5 min), hourly (jitter 60 min)."
Write-Output "Logs:     $(Join-ZuidWestPath 'Logs', 'policy-auto-update.log')"
Write-Output ""
Write-Output "=== Policy Auto-Update Installation complete ==="

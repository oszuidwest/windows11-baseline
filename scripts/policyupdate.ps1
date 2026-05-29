param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$installedSha,
    [bool]$seedInstalledSha
)

<#
.SYNOPSIS
    Installs the scheduled policy auto-updater.

.DESCRIPTION
    Writes state under C:\ProgramData\ZuidWest\policy-update, copies the
    auto-updater payload there, and registers \ZuidWest\PolicyAutoUpdate.
    The task runs as SYSTEM at startup, logon, and hourly with jitter; it polls
    github.com's commits.atom feed and reapplies policies/AppLocker when the
    SHA or deployment context changes.

    Full installs seed the downloaded SHA to avoid a duplicate first apply.
    -OnlyRun policyupdate refreshes state and task registration without seeding
    unless policies and applocker ran in the same invocation.

.PARAMETER systemPurpose
    radio, tv, editorial, or plain.

.PARAMETER systemOwnership
    shared, personal, or dedicated.
#>

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_common.ps1")

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

# Preserve applied SHAs across task refreshes to avoid redundant re-apply.
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

# Context changes must force a re-apply even if main has not advanced.
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

$action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$updaterPath`""

# Jitter prevents fleet-wide boot/logon bursts against github.com.
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

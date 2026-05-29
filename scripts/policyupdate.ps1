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
      - state.json.bak    Previous generation, kept by Save-DeploymentStateAtomic
      - update.ps1        Copy of scripts/lib/policy-auto-updater.ps1
      - staging/          Created/destroyed per run (download workspace)

    Scheduled Task: \ZuidWest\PolicyAutoUpdate
      - Runs as SYSTEM at: system startup, any user logon, hourly
      - The hourly trigger uses a per-install random minute offset stored in
        state.pollOffsetMinutes so a fleet behind one NAT spreads the
        unauthenticated GitHub API checks across the hour instead of all
        firing in lockstep.
      - The updater itself uses conditional ETag requests, so steady-state
        polling does not burn rate-limit quota.

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
    schemaVersion     = 2
    repoOwner         = "oszuidwest"
    repoName          = "windows11-baseline"
    branch            = "main"
    systemPurpose     = $systemPurpose.ToLower()
    systemOwnership   = $systemOwnership.ToLower()
    scriptsToReapply  = @("policies", "applocker")
    pollOffsetMinutes = Get-Random -Minimum 0 -Maximum 60
    lastAppliedSha    = $null
    lastAppliedAt     = $null
    lastSelfUpdateSha = $null
    lastEtag          = $null
    lastCheckAt       = $null
    backoffUntil      = $null
}

if (Test-Path $statePath) {
    try {
        $previous = Read-DeploymentState -Path $statePath
        foreach ($key in @("lastAppliedSha", "lastAppliedAt", "lastSelfUpdateSha", "lastEtag", "lastCheckAt", "backoffUntil", "pollOffsetMinutes")) {
            if ($previous.PSObject.Properties.Name -contains $key -and $null -ne $previous.$key) {
                $state[$key] = $previous.$key
            }
        }
    }
    catch {
        Write-Warning "Could not read existing state file ($_); starting fresh."
    }
}

Save-DeploymentStateAtomic -Path $statePath -State $state
Write-Output "Deployment state: $statePath"
Write-Output "  Purpose:    $($state.systemPurpose)"
Write-Output "  Ownership:  $($state.systemOwnership)"
Write-Output "  Repo:       $($state.repoOwner)/$($state.repoName)@$($state.branch)"
Write-Output "  Re-apply:   $($state.scriptsToReapply -join ', ')"
Write-Output "  Poll offset:$($state.pollOffsetMinutes) min past the hour"

Copy-Item -Path $payloadSource -Destination $updaterPath -Force
Write-Output "Updater payload: $updaterPath"

# Register / refresh the Scheduled Task.
$action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$updaterPath`""

$startupTrigger = New-ScheduledTaskTrigger -AtStartup
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn

# Hourly: a -Once trigger anchored shortly after install plus a per-install
# random minute offset, repeating every hour for a far-future duration. The
# offset spreads the fleet's polling across the hour so a small office NAT
# does not burn the unauthenticated GitHub API budget at xx:00 every hour.
$hourlyTrigger = New-ScheduledTaskTrigger `
    -Once -At (Get-Date).AddMinutes(5 + $state.pollOffsetMinutes) `
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
    -Description "Streekomroep ZuidWest baseline policy auto-update. Polls GitHub (conditional requests, ETag cache, backoff on 403/429) for new commits on the configured branch and re-applies the policies + AppLocker layer when the SHA changes."

Register-ScheduledTask -TaskName $taskName -TaskPath $taskFolder -InputObject $task -Force | Out-Null
Write-Output "Scheduled Task registered: $taskFullPath"

Write-Output ""
Write-Output "Triggers: system startup, any user logon, hourly (offset +$($state.pollOffsetMinutes) min)."
Write-Output "Logs:     $(Join-Path $env:ProgramData 'ZuidWest\Logs\policy-auto-update.log')"
Write-Output ""
Write-Output "=== Policy Auto-Update Installation complete ==="

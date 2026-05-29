<#
.SYNOPSIS
    Scheduled-task payload that re-applies the ZuidWest baseline policy layer
    whenever the configured GitHub branch advances.

.DESCRIPTION
    Runs as SYSTEM under the "ZuidWest\PolicyAutoUpdate" Scheduled Task.
    Reads its deployment state from C:\ProgramData\ZuidWest\policy-update\state.json
    (written at install time by scripts/policyupdate.ps1), asks the GitHub API
    for the HEAD commit SHA of the configured branch, and short-circuits when
    that SHA matches the SHA last applied to this machine.

    On a new SHA the script:

      1. Downloads the repository archive for that exact SHA into a staging
         directory under C:\ProgramData\ZuidWest\policy-update\staging.
      2. Points the baseline's deploy-path override
         ($env:WINDOWS11_BASELINE_DEPLOY_PATH) at the staging directory so
         the existing sub-scripts (which use Get-DeployPath / Join-DeployPath
         from scripts/_common.ps1) operate on the freshly downloaded copy
         without touching C:\Windows\deploy.
      3. Runs each script listed in state.scriptsToReapply (default: policies,
         applocker), passing systemPurpose / systemOwnership from the state
         file. Sub-scripts are invoked directly, not via install.ps1, so the
         updater is fully non-interactive.
      4. Persists the new SHA, copies the latest version of this payload from
         the staging directory back over its install location, and removes the
         staging directory.

    A single-instance file lock prevents overlapping runs when multiple
    triggers fire close together (e.g. boot + logon).

.NOTES
    Source file: scripts/lib/policy-auto-updater.ps1
    Installed to: C:\ProgramData\ZuidWest\policy-update\update.ps1
    Deployed by: scripts/policyupdate.ps1
    Log:         C:\ProgramData\ZuidWest\Logs\policy-auto-update.log
#>

$ErrorActionPreference = "Stop"

$persistentRoot = Join-Path $env:ProgramData "ZuidWest\policy-update"
$statePath = Join-Path $persistentRoot "state.json"
$stagingRoot = Join-Path $persistentRoot "staging"
$logDir = Join-Path $env:ProgramData "ZuidWest\Logs"
$logPath = Join-Path $logDir "policy-auto-update.log"
$lockPath = Join-Path $persistentRoot "update.lock"
$selfPath = $PSCommandPath

function Write-UpdateLog {
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    $line = "$timestamp [$Level] $Message"
    try {
        Add-Content -Path $logPath -Value $line -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        # Best-effort logging: never let the log writer itself break the updater.
        $null = $_
    }
    Write-Output $line
}

if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Rotate the log once it grows past ~5 MB to keep deploys tidy without losing recent history.
if (Test-Path $logPath) {
    try {
        if ((Get-Item $logPath).Length -gt 5MB) {
            Move-Item -Path $logPath -Destination "$logPath.1" -Force
        }
    }
    catch {
        # Non-fatal: continue writing to the existing log.
        $null = $_
    }
}

# Single-instance lock. Boot + logon triggers can fire seconds apart; ignore overlapping runs.
$lockStream = $null
try {
    $lockStream = [System.IO.File]::Open($lockPath, 'Create', 'Write', 'None')
}
catch {
    Write-UpdateLog "Another auto-update run is in progress; skipping."
    return
}

try {
    if (-not (Test-Path $statePath)) {
        Write-UpdateLog "State file missing at $statePath; refusing to run." "ERROR"
        return
    }

    $state = Get-Content -Path $statePath -Raw | ConvertFrom-Json

    $repoOwner = $state.repoOwner
    $repoName = $state.repoName
    $branch = $state.branch
    $purpose = $state.systemPurpose
    $ownership = $state.systemOwnership
    $scriptsToReapply = @($state.scriptsToReapply)

    if (-not $repoOwner -or -not $repoName -or -not $branch) {
        Write-UpdateLog "State file is missing repoOwner/repoName/branch; aborting." "ERROR"
        return
    }

    Write-UpdateLog "Checking $repoOwner/$repoName@$branch (purpose=$purpose, ownership=$ownership)."

    # Resolve the current branch HEAD SHA via the GitHub API.
    $apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/commits/$branch"
    $headers = @{
        "User-Agent" = "windows11-baseline-policy-auto-update"
        "Accept"     = "application/vnd.github+json"
    }

    $previousProgress = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"
    try {
        $apiResponse = Invoke-RestMethod -Uri $apiUrl -Headers $headers -UseBasicParsing -TimeoutSec 30
    }
    catch {
        Write-UpdateLog "GitHub API call failed: $($_.Exception.Message)" "ERROR"
        return
    }
    finally {
        $ProgressPreference = $previousProgress
    }

    $remoteSha = $apiResponse.sha
    if (-not $remoteSha) {
        Write-UpdateLog "GitHub API response did not include a SHA; aborting." "ERROR"
        return
    }

    # Record the check time even when there is nothing to apply.
    $now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $state.lastCheckAt = $now
    $state | ConvertTo-Json -Depth 4 | Set-Content -Path $statePath -Encoding UTF8

    if ($state.lastAppliedSha -eq $remoteSha) {
        Write-UpdateLog "Already at $remoteSha; nothing to do."
        return
    }

    Write-UpdateLog "New SHA $remoteSha (was $($state.lastAppliedSha)); preparing staged apply."

    if (Test-Path $stagingRoot) {
        Remove-Item -Path $stagingRoot -Recurse -Force
    }
    New-Item -Path $stagingRoot -ItemType Directory -Force | Out-Null

    $zipUrl = "https://github.com/$repoOwner/$repoName/archive/$remoteSha.zip"
    $zipPath = Join-Path $stagingRoot "repo.zip"

    $previousProgress = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"
    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -TimeoutSec 120
    }
    catch {
        Write-UpdateLog "Failed to download repo archive: $($_.Exception.Message)" "ERROR"
        return
    }
    finally {
        $ProgressPreference = $previousProgress
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $stagingRoot)
    Remove-Item -Path $zipPath -Force

    # GitHub archives extract to <repo>-<sha>/...; flatten so $stagingRoot is the repo root.
    $extracted = Get-ChildItem -Path $stagingRoot -Directory | Select-Object -First 1
    if (-not $extracted) {
        Write-UpdateLog "Extracted archive did not contain a directory; aborting." "ERROR"
        return
    }
    Get-ChildItem -Path $extracted.FullName -Force | Move-Item -Destination $stagingRoot -Force
    Remove-Item -Path $extracted.FullName -Recurse -Force

    $commonPath = Join-Path $stagingRoot "scripts\_common.ps1"
    if (-not (Test-Path $commonPath)) {
        Write-UpdateLog "Staging is missing scripts\_common.ps1; aborting." "ERROR"
        return
    }

    # Redirect Get-DeployPath to the staging directory so policies.ps1 / applocker.ps1
    # read their inputs (policies/, bin/) from the freshly downloaded copy instead of
    # C:\Windows\deploy. install.ps1 might be running concurrently; this keeps us isolated.
    $env:WINDOWS11_BASELINE_DEPLOY_PATH = $stagingRoot
    try {
        . $commonPath

        foreach ($scriptName in $scriptsToReapply) {
            $candidates = @(
                (Join-Path $stagingRoot "scripts\$scriptName.ps1"),
                (Join-Path $stagingRoot "scripts\_$scriptName.ps1")
            )
            $scriptPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
            if (-not $scriptPath) {
                Write-UpdateLog "Script '$scriptName' not found in staging; skipping." "WARN"
                continue
            }

            $detectedParams = Get-ScriptParameterNames -Path $scriptPath
            $scriptParams = @{}
            $unsupportedParam = $null
            foreach ($paramName in $detectedParams) {
                switch ($paramName) {
                    "systemPurpose" { $scriptParams["systemPurpose"] = $purpose }
                    "systemOwnership" { $scriptParams["systemOwnership"] = $ownership }
                    default { $unsupportedParam = $paramName }
                }
            }

            if ($unsupportedParam) {
                Write-UpdateLog "Script '$scriptName' declares -$unsupportedParam which the auto-updater cannot supply; aborting." "ERROR"
                return
            }

            Write-UpdateLog "Running $scriptName..."
            $childOutput = & $scriptPath @scriptParams *>&1
            foreach ($entry in $childOutput) {
                $text = if ($entry -is [string]) { $entry } else { $entry.ToString() }
                foreach ($line in ($text -split "`r?`n")) {
                    if ($line) {
                        Write-UpdateLog "[$scriptName] $line"
                    }
                }
            }
        }
    }
    finally {
        Remove-Item -Path "Env:WINDOWS11_BASELINE_DEPLOY_PATH" -ErrorAction SilentlyContinue
    }

    $state.lastAppliedSha = $remoteSha
    $state.lastAppliedAt = $now
    $state | ConvertTo-Json -Depth 4 | Set-Content -Path $statePath -Encoding UTF8

    # Refresh the deployed copy of this script so updater fixes shipped via main propagate.
    $newSelf = Join-Path $stagingRoot "scripts\lib\policy-auto-updater.ps1"
    if (Test-Path $newSelf) {
        try {
            Copy-Item -Path $newSelf -Destination $selfPath -Force
            Write-UpdateLog "Auto-updater payload refreshed at $selfPath."
        }
        catch {
            Write-UpdateLog "Could not refresh auto-updater payload (will retry next run): $($_.Exception.Message)" "WARN"
        }
    }

    Write-UpdateLog "Applied $remoteSha."
}
catch {
    Write-UpdateLog "Auto-update failed: $($_.Exception.Message)" "ERROR"
}
finally {
    if ($lockStream) {
        $lockStream.Dispose()
    }
    Remove-Item -Path $lockPath -ErrorAction SilentlyContinue
    if (Test-Path $stagingRoot) {
        Remove-Item -Path $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

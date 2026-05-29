<#
.SYNOPSIS
    Scheduled-task payload that re-applies the ZuidWest baseline policy layer
    whenever the configured GitHub branch advances.

.DESCRIPTION
    Runs as SYSTEM. It checks GitHub's commits.atom feed for the configured
    branch, downloads the exact SHA into staging, runs the configured policy
    scripts from that staged copy, and refreshes this updater when needed.

    State is stored under C:\ProgramData\ZuidWest\policy-update. Policy and
    self-update SHAs are tracked separately so one successful stage is not
    repeated because the other failed. State writes are atomic with a .bak
    fallback; a file lock drops overlapping boot/logon runs.

    The updater uses the public atom feed instead of api.github.com and honors
    Retry-After / X-RateLimit-* backoff headers when github.com rate-limits.

.NOTES
    Source file: scripts/lib/policy-auto-updater.ps1
    Installed to: C:\ProgramData\ZuidWest\policy-update\update.ps1
    Deployed by: scripts/policyupdate.ps1
    Log:         C:\ProgramData\ZuidWest\Logs\policy-auto-update.log
#>

$ErrorActionPreference = "Stop"

$zuidWestRoot = Join-Path $env:ProgramData "ZuidWest"
$persistentRoot = Join-Path $zuidWestRoot "policy-update"
$statePath = Join-Path $persistentRoot "state.json"
$stagingRoot = Join-Path $persistentRoot "staging"
$logDir = Join-Path $zuidWestRoot "Logs"
$logPath = Join-Path $logDir "policy-auto-update.log"
$lockPath = Join-Path $persistentRoot "update.lock"
$selfPath = $PSCommandPath

# Needed before staged _common.ps1 is available.
function Save-StateAtomicLocal {
    param (
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$State
    )
    $tmpPath = "$Path.tmp"
    $bakPath = "$Path.bak"
    $State | ConvertTo-Json -Depth 6 | Set-Content -Path $tmpPath -Encoding UTF8 -Force
    if (Test-Path $Path) {
        [System.IO.File]::Replace($tmpPath, $Path, $bakPath)
    }
    else {
        Move-Item -Path $tmpPath -Destination $Path -Force
    }
}

function Read-StateOrBakLocal {
    param ([Parameter(Mandatory)][string]$Path)
    try {
        return Get-Content -Path $Path -Raw | ConvertFrom-Json
    }
    catch {
        $bakPath = "$Path.bak"
        if (Test-Path $bakPath) {
            Write-UpdateLog "State at $Path corrupt; falling back to $bakPath." "WARN"
            return Get-Content -Path $bakPath -Raw | ConvertFrom-Json
        }
        throw
    }
}

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
        # Logging must never break the updater.
        $null = $_
    }
    Write-Output $line
}

function Get-BackoffUntilFromHeaders {
    <#
    .SYNOPSIS
        Compute when polling may resume after a 403/429 from github.com.

    .DESCRIPTION
        Follows GitHub's retry ordering: Retry-After first, then
        X-RateLimit-Reset when remaining is 0, otherwise a 1-minute floor.
        Returns a UTC DateTime.
    #>
    [OutputType([datetime])]
    param ($Headers)

    $now = (Get-Date).ToUniversalTime()

    if (-not $Headers) {
        return $now.AddMinutes(1)
    }

    $retryRaw = $Headers["Retry-After"]
    if ($retryRaw) {
        $seconds = 0
        if ([int]::TryParse([string]$retryRaw, [ref]$seconds) -and $seconds -gt 0) {
            return $now.AddSeconds($seconds)
        }
    }

    $remaining = -1
    $remainingRaw = $Headers["X-RateLimit-Remaining"]
    if ($remainingRaw) {
        [int]::TryParse([string]$remainingRaw, [ref]$remaining) | Out-Null
    }
    if ($remaining -eq 0) {
        $resetRaw = $Headers["X-RateLimit-Reset"]
        if ($resetRaw) {
            $epoch = 0
            if ([int]::TryParse([string]$resetRaw, [ref]$epoch) -and $epoch -gt 0) {
                return [DateTimeOffset]::FromUnixTimeSeconds($epoch).UtcDateTime
            }
        }
    }

    return $now.AddMinutes(1)
}

function Invoke-AtomBranchCheck {
    <#
    .SYNOPSIS
        Resolve a branch's HEAD commit SHA via the public commits.atom feed.

    .DESCRIPTION
        Returns Status="ok" with .Sha, or Status="rateLimited" with
        .BackoffUntil and .StatusCode. Other errors throw.
    #>
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$Branch
    )

    $url = "https://github.com/$Owner/$Repo/commits/$Branch.atom"
    $headers = @{
        "User-Agent" = "windows11-baseline-policy-auto-update"
        "Accept"     = "application/atom+xml"
    }

    $previousProgress = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"
    try {
        $response = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing -TimeoutSec 30
    }
    catch [System.Net.WebException] {
        $webResponse = $_.Exception.Response
        if ($null -eq $webResponse) {
            throw
        }
        $statusCode = [int]$webResponse.StatusCode
        if ($statusCode -eq 403 -or $statusCode -eq 429) {
            $until = Get-BackoffUntilFromHeaders -Headers $webResponse.Headers
            return [pscustomobject]@{ Status = "rateLimited"; BackoffUntil = $until; StatusCode = $statusCode }
        }
        if ($statusCode -eq 404) {
            throw "Atom feed at $url returned 404; branch '$Branch' may not exist."
        }
        throw
    }
    finally {
        $ProgressPreference = $previousProgress
    }

    if ($response.Content -match 'tag:github\.com,2008:Grit::Commit/([a-fA-F0-9]{40})') {
        return [pscustomobject]@{
            Status = "ok"
            Sha    = $Matches[1].ToLower()
        }
    }

    throw "Could not parse latest commit SHA from atom feed at $url."
}

if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Keep one rotated log generation.
if (Test-Path $logPath) {
    try {
        if ((Get-Item $logPath).Length -gt 5MB) {
            Move-Item -Path $logPath -Destination "$logPath.1" -Force
        }
    }
    catch {
        $null = $_
    }
}

# Boot and logon triggers can overlap.
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

    $state = Read-StateOrBakLocal -Path $statePath

    # Backfill newer state fields.
    $schemaDefaults = @{
        enabled           = $true
        lastSelfUpdateSha = $null
        backoffUntil      = $null
        lastCheckAt       = $null
    }
    foreach ($field in $schemaDefaults.Keys) {
        if (-not ($state.PSObject.Properties.Name -contains $field)) {
            $state | Add-Member -NotePropertyName $field -NotePropertyValue $schemaDefaults[$field] -Force
        }
    }

    $enabled = $true
    try {
        $enabled = [System.Convert]::ToBoolean($state.enabled)
    }
    catch {
        Write-UpdateLog "State field 'enabled' is not a boolean-compatible value; treating auto-update as enabled." "WARN"
    }
    if (-not $enabled) {
        Write-UpdateLog "Auto-update disabled by state.enabled=false; skipping."
        return
    }

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

    # Do not touch the network during backoff.
    if ($state.backoffUntil) {
        $until = [datetime]::MinValue
        if ([datetime]::TryParse([string]$state.backoffUntil, [ref]$until)) {
            $untilUtc = $until.ToUniversalTime()
            if ((Get-Date).ToUniversalTime() -lt $untilUtc) {
                Write-UpdateLog "Backoff active until $($untilUtc.ToString('o')); skipping."
                return
            }
        }
    }

    Write-UpdateLog "Checking $repoOwner/$repoName@$branch (purpose=$purpose, ownership=$ownership)."

    $check = Invoke-AtomBranchCheck -Owner $repoOwner -Repo $repoName -Branch $branch

    $now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    if ($check.Status -eq "rateLimited") {
        $state.backoffUntil = $check.BackoffUntil.ToString("yyyy-MM-ddTHH:mm:ssZ")
        $state.lastCheckAt = $now
        Save-StateAtomicLocal -Path $statePath -State $state
        Write-UpdateLog "github.com returned $($check.StatusCode); backoff until $($state.backoffUntil)." "WARN"
        return
    }

    # Clear stale backoff after a successful check.
    $state.backoffUntil = $null
    $state.lastCheckAt = $now

    $remoteSha = $check.Sha
    if (-not $remoteSha) {
        Write-UpdateLog "Atom feed did not contain a SHA; aborting." "ERROR"
        return
    }

    $policyCurrent = $state.lastAppliedSha -eq $remoteSha
    $selfCurrent = $state.lastSelfUpdateSha -eq $remoteSha

    if ($policyCurrent -and $selfCurrent) {
        Save-StateAtomicLocal -Path $statePath -State $state
        Write-UpdateLog "Already at $remoteSha; nothing to do."
        return
    }

    Write-UpdateLog "Stale: policy=$(-not $policyCurrent), self=$(-not $selfCurrent). Target SHA $remoteSha; preparing staged apply."

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

    # Flatten GitHub's <repo>-<sha>/ archive wrapper.
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

    # Run sub-scripts against staging, isolated from any concurrent install.
    $env:WINDOWS11_BASELINE_DEPLOY_PATH = $stagingRoot
    try {
        . $commonPath

        if (-not $policyCurrent) {
            foreach ($scriptName in $scriptsToReapply) {
                $candidates = @(
                    (Join-Path $stagingRoot "scripts\$scriptName.ps1"),
                    (Join-Path $stagingRoot "scripts\_$scriptName.ps1")
                )
                $scriptPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
                if (-not $scriptPath) {
                    # Do not advance lastAppliedSha when requested scripts are missing.
                    Write-UpdateLog "Script '$scriptName' is in scriptsToReapply but not found in staging; aborting (lastAppliedSha not advanced)." "ERROR"
                    return
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

            # Self-update failure should not force policy re-apply.
            $state.lastAppliedSha = $remoteSha
            $state.lastAppliedAt = $now
            Save-StateAtomicLocal -Path $statePath -State $state
            Write-UpdateLog "Applied policy SHA $remoteSha."
        }
        else {
            Write-UpdateLog "Policy already at $remoteSha; only refreshing the deployed updater."
        }
    }
    finally {
        Remove-Item -Path "Env:WINDOWS11_BASELINE_DEPLOY_PATH" -ErrorAction SilentlyContinue
    }

    if (-not $selfCurrent) {
        # Retry independently via lastSelfUpdateSha when this copy fails.
        $newSelf = Join-Path $stagingRoot "scripts\lib\policy-auto-updater.ps1"
        if (-not (Test-Path $newSelf)) {
            Write-UpdateLog "Staging does not contain scripts\lib\policy-auto-updater.ps1; skipping self-update." "WARN"
        }
        else {
            try {
                Copy-Item -Path $newSelf -Destination $selfPath -Force
                $state.lastSelfUpdateSha = $remoteSha
                Save-StateAtomicLocal -Path $statePath -State $state
                Write-UpdateLog "Auto-updater payload refreshed at $selfPath."
            }
            catch {
                Write-UpdateLog "Self-update copy failed (will retry next run): $($_.Exception.Message)" "WARN"
            }
        }
    }
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

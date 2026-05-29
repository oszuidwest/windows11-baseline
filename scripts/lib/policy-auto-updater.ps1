<#
.SYNOPSIS
    Scheduled-task payload that re-applies the ZuidWest baseline policy layer
    whenever the configured GitHub branch advances.

.DESCRIPTION
    Runs as SYSTEM under the "ZuidWest\PolicyAutoUpdate" Scheduled Task.
    Reads its deployment state from C:\ProgramData\ZuidWest\policy-update\state.json
    (written at install time by scripts/policyupdate.ps1), asks the GitHub API
    for the HEAD commit SHA of the configured branch, and short-circuits when
    that SHA matches the SHAs already applied on this machine.

    Rate-limit posture (GitHub unauthenticated cap is 60 req/h/IP):
      - Conditional requests via If-None-Match always save bandwidth on the
        steady-state poll. Whether the 304 also avoids spending rate-limit
        quota is documented as conditional on the request being
        authenticated, so this implementation does not rely on it for the
        unauthenticated case; the backoff handler below is the actual
        defence.
      - On 403/429 the response headers are honoured per GitHub's REST API
        best practices: Retry-After takes precedence (it signals the
        secondary / abuse-detection limit), then X-RateLimit-Reset is used
        only when X-RateLimit-Remaining is 0, with a 1-minute floor
        fallback. The resulting wake time is persisted to state.backoffUntil
        and short-circuits subsequent ticks until it passes.
      - The scheduled-task trigger anchored by policyupdate.ps1 uses
        -RandomDelay so each fleet member fires at a different minute
        within the hour.

    On a SHA that differs from either state.lastAppliedSha (policies need
    re-running) or state.lastSelfUpdateSha (the deployed copy of this script
    is out of date) the updater:

      1. Downloads the repository archive for that exact SHA into a staging
         directory under C:\ProgramData\ZuidWest\policy-update\staging.
      2. Points the baseline's deploy-path override
         ($env:WINDOWS11_BASELINE_DEPLOY_PATH) at the staging directory so
         the existing sub-scripts (which use Get-DeployPath / Join-DeployPath
         from scripts/_common.ps1) operate on the freshly downloaded copy
         without touching C:\Windows\deploy.
      3. If policy is stale: runs each script listed in state.scriptsToReapply
         (default: policies, applocker), passing systemPurpose /
         systemOwnership from the state file. Sub-scripts are invoked
         directly, not via install.ps1, so the updater is fully
         non-interactive.
      4. If the self-copy is stale: copies the staged
         scripts/lib/policy-auto-updater.ps1 over this script.
      5. Persists progress per stage. Policy SHA and self-update SHA are
         tracked separately, so a self-copy that fails (file locked, AV
         scanning) does not prevent the retry on the next tick.

    State writes use Save-StateAtomicLocal (defined inline at startup so it
    is available before the staged scripts/_common.ps1 is sourced). Reads use
    Read-StateOrBakLocal, which falls back to "$statePath.bak" if the main
    file fails to parse. This protects the updater from being permanently
    bricked by a power loss or crash mid-write.

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

# Inline copies of the atomic state helpers. The canonical implementations
# live in scripts/_common.ps1, but we need them before the staged _common.ps1
# is sourced (we have to read state.json to know which repo to download from).
# Re-defining them after dot-sourcing is harmless: the bodies are identical.
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
        # Best-effort logging: never let the log writer itself break the updater.
        $null = $_
    }
    Write-Output $line
}

function Get-BackoffUntilFromHeaders {
    <#
    .SYNOPSIS
        Compute when polling may resume after a 403/429 from the GitHub API.

    .DESCRIPTION
        Implements the resume-time logic from GitHub's REST API best practices
        guide (https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api):

          1. If Retry-After is set, wait that many seconds (it carries the
             secondary / abuse-detection limit and takes precedence).
          2. Otherwise, if X-RateLimit-Remaining is 0, wait until
             X-RateLimit-Reset (Unix epoch seconds, the primary-limit reset).
          3. Otherwise fall back to a 1-minute floor; subsequent scheduled
             ticks effectively give us exponential spacing across the hour.

        Output is a DateTime in UTC.
    #>
    [OutputType([datetime])]
    param ($Headers)

    $now = (Get-Date).ToUniversalTime()

    if (-not $Headers) {
        return $now.AddMinutes(1)
    }

    # 1. Retry-After wins when set: secondary rate / abuse detection.
    $retryRaw = $Headers["Retry-After"]
    if ($retryRaw) {
        $seconds = 0
        if ([int]::TryParse([string]$retryRaw, [ref]$seconds) -and $seconds -gt 0) {
            return $now.AddSeconds($seconds)
        }
    }

    # 2. Primary limit exhausted (Remaining == 0): honour X-RateLimit-Reset.
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

    # 3. No header hints: GitHub recommends at least one minute before retry.
    return $now.AddMinutes(1)
}

function Invoke-GitHubApiCommitCheck {
    <#
    .SYNOPSIS
        Conditional GET against /commits/<branch> with ETag caching.

    .DESCRIPTION
        Returns a pscustomobject with one of three shapes:
          Status="ok"        : new data; .Sha and .Etag populated
          Status="notModified": 304 response; ETag unchanged
          Status="rateLimited": 403/429; .BackoffUntil populated
        Network failure throws.
    #>
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$Branch,
        [string]$Etag
    )

    $url = "https://api.github.com/repos/$Owner/$Repo/commits/$Branch"
    $headers = @{
        "User-Agent" = "windows11-baseline-policy-auto-update"
        "Accept"     = "application/vnd.github+json"
    }
    if ($Etag) {
        $headers["If-None-Match"] = $Etag
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
        if ($statusCode -eq 304) {
            return [pscustomobject]@{ Status = "notModified" }
        }
        if ($statusCode -eq 403 -or $statusCode -eq 429) {
            $until = Get-BackoffUntilFromHeaders -Headers $webResponse.Headers
            return [pscustomobject]@{ Status = "rateLimited"; BackoffUntil = $until; StatusCode = $statusCode }
        }
        throw
    }
    finally {
        $ProgressPreference = $previousProgress
    }

    $parsed = $response.Content | ConvertFrom-Json
    $newEtag = $response.Headers["ETag"]
    if ($newEtag -is [array]) { $newEtag = $newEtag[0] }
    return [pscustomobject]@{
        Status = "ok"
        Sha    = $parsed.sha
        Etag   = $newEtag
    }
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

    $state = Read-StateOrBakLocal -Path $statePath

    # Ensure newer schema fields exist even when reading an older state file.
    foreach ($field in @('lastSelfUpdateSha', 'lastEtag', 'backoffUntil', 'lastCheckAt')) {
        if (-not ($state.PSObject.Properties.Name -contains $field)) {
            $state | Add-Member -NotePropertyName $field -NotePropertyValue $null -Force
        }
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

    # Honour any active backoff window before doing anything that touches the network.
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

    # Send a conditional request. Only the first request (or after a real change)
    # spends a unit of the unauthenticated rate-limit budget; 304s are free.
    $check = Invoke-GitHubApiCommitCheck -Owner $repoOwner -Repo $repoName -Branch $branch -Etag $state.lastEtag

    $now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    if ($check.Status -eq "rateLimited") {
        $state.backoffUntil = $check.BackoffUntil.ToString("yyyy-MM-ddTHH:mm:ssZ")
        $state.lastCheckAt = $now
        Save-StateAtomicLocal -Path $statePath -State $state
        Write-UpdateLog "GitHub API returned $($check.StatusCode); backoff until $($state.backoffUntil)." "WARN"
        return
    }

    # Clear any stale backoff now that the API is answering normally again.
    $state.backoffUntil = $null
    $state.lastCheckAt = $now

    if ($check.Status -eq "notModified") {
        # Server confirms our cached version is current. Use the SHA we last applied
        # as the target so we can still retry a stalled self-copy from this run.
        $remoteSha = $state.lastAppliedSha
        if (-not $remoteSha) {
            # We have an ETag but no recorded SHA (unusual). Force a fresh request
            # next tick by dropping the ETag.
            $state.lastEtag = $null
            Save-StateAtomicLocal -Path $statePath -State $state
            Write-UpdateLog "304 received but no lastAppliedSha; cleared ETag, will fetch full payload next tick." "WARN"
            return
        }
        Write-UpdateLog "API returned 304 (no change); target SHA $remoteSha."
        $pendingEtag = $state.lastEtag
    }
    else {
        $remoteSha = $check.Sha
        if (-not $remoteSha) {
            Write-UpdateLog "GitHub API response did not include a SHA; aborting." "ERROR"
            return
        }
        # The new ETag goes into state ONLY after a successful apply below; if we
        # crash between here and there, the next tick will re-fetch the same SHA.
        $pendingEtag = $check.Etag
    }

    $policyCurrent = $state.lastAppliedSha -eq $remoteSha
    $selfCurrent = $state.lastSelfUpdateSha -eq $remoteSha

    if ($policyCurrent -and $selfCurrent) {
        # Fully caught up. Persist lastCheckAt (and, on a fresh 200, the new ETag).
        if ($check.Status -eq "ok") {
            $state.lastEtag = $pendingEtag
        }
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

        if (-not $policyCurrent) {
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

            # Persist policy progress before attempting the self-copy so a failure
            # there does not force a re-apply on the next tick.
            $state.lastAppliedSha = $remoteSha
            $state.lastAppliedAt = $now
            if ($check.Status -eq "ok") {
                $state.lastEtag = $pendingEtag
            }
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
        # Refresh the deployed copy of this script so updater fixes shipped via main
        # propagate. Track success separately from the policy SHA: a failed copy
        # (file locked, AV scan) will be retried on the next tick because
        # lastSelfUpdateSha stays behind lastAppliedSha and the short-circuit at
        # the top of the run only fires when BOTH match the target.
        $newSelf = Join-Path $stagingRoot "scripts\lib\policy-auto-updater.ps1"
        if (-not (Test-Path $newSelf)) {
            Write-UpdateLog "Staging does not contain scripts\lib\policy-auto-updater.ps1; skipping self-update." "WARN"
        }
        else {
            try {
                Copy-Item -Path $newSelf -Destination $selfPath -Force
                $state.lastSelfUpdateSha = $remoteSha
                if ($check.Status -eq "ok") {
                    $state.lastEtag = $pendingEtag
                }
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

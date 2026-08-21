param(
    # Validated after download to avoid a stale ValidateSet.
    [string[]]$OnlyRun
)

$ErrorActionPreference = "Stop"

$script:ZuidWestRoot = Join-Path $env:ProgramData "ZuidWest"
$script:InstallLogRoot = Join-Path $script:ZuidWestRoot "Logs"
$script:DeployRoot = Join-Path $script:ZuidWestRoot "deploy"
$script:RepoOwner = "oszuidwest"
$script:RepoName = "windows11-baseline"
$script:RepoBranch = "main"

function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
    (New-Object Security.Principal.WindowsPrincipal $currentUser).IsInRole($adminRole)
}

$script:InstallLogPath = $null

function Initialize-InstallLog {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logDirectories = @(
        $script:InstallLogRoot,
        $env:TEMP
    )

    foreach ($logDirectory in $logDirectories) {
        try {
            if (-not (Test-Path $logDirectory)) {
                New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
            }

            $candidate = Join-Path $logDirectory "windows11-baseline-$timestamp.log"
            Start-Transcript -Path $candidate -Force | Out-Null
            $script:InstallLogPath = $candidate
            $env:WINDOWS11_BASELINE_TRANSCRIPT_PATH = $candidate
            Write-Output "Log file: $script:InstallLogPath"
            return
        }
        catch {
            Write-Verbose "Could not start transcript in ${logDirectory}: $($_.Exception.Message)"
        }
    }

    Write-Warning "Could not start transcript logging."
}

function Close-InstallLog {
    if (-not $env:WINDOWS11_BASELINE_TRANSCRIPT_PATH) {
        return
    }
    try {
        Stop-Transcript | Out-Null
    }
    catch {
        Write-Verbose "Could not stop transcript: $($_.Exception.Message)"
    }
    finally {
        Remove-Item -Path "Env:WINDOWS11_BASELINE_TRANSCRIPT_PATH" -ErrorAction SilentlyContinue
    }
}

function Wait-BeforeExit {
    param (
        [string]$Prompt = "Press Enter to exit..."
    )

    Read-Host -Prompt $Prompt | Out-Null
}

function Resolve-GitHubBranchSha {
    param (
        [Parameter(Mandatory)]
        [string]$Owner,

        [Parameter(Mandatory)]
        [string]$Repo,

        [Parameter(Mandatory)]
        [string]$Branch
    )

    $url = "https://github.com/$Owner/$Repo/commits/$Branch.atom"
    $headers = @{
        "User-Agent" = "windows11-baseline-installer"
        "Accept"     = "application/atom+xml"
    }

    $previousProgressPreference = $ProgressPreference
    try {
        $ProgressPreference = "SilentlyContinue"
        $response = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
    }
    finally {
        $ProgressPreference = $previousProgressPreference
    }

    if ($response.Content -match 'tag:github\.com,2008:Grit::Commit/([a-fA-F0-9]{40})') {
        return $Matches[1].ToLower()
    }

    throw "Could not resolve latest commit SHA from $url"
}

function Write-FatalInstallError {
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [object]$ErrorRecord,

        [int]$ExitCode = 1
    )

    Write-Output ""
    Write-Error -Message $Message -ErrorAction Continue
    if ($ErrorRecord) {
        Write-Output "Details: $ErrorRecord"
    }
    if ($script:InstallLogPath) {
        Write-Output "Log file: $script:InstallLogPath"
    }

    Close-InstallLog
    Wait-BeforeExit
    exit $ExitCode
}

function Complete-Install {
    if ($script:InstallLogPath) {
        Write-Output "Log file: $script:InstallLogPath"
    }

    Close-InstallLog
    Wait-BeforeExit
    exit 0
}

Initialize-InstallLog

trap {
    Write-FatalInstallError -Message "Unexpected fatal error." -ErrorRecord $_
}

if (-not (Test-Admin)) {
    Write-FatalInstallError -Message "This script must be run as an administrator. Exiting..."
}

Write-Output ""
Write-Output "=========================================="
Write-Output " Windows 11 Baseline - Streekomroep ZuidWest"
Write-Output "=========================================="
Write-Output ""
Write-Output "This script will configure a Windows 11 system with the specified settings."
Write-Output ""

# Download first so _common.ps1 can validate later prompts.
$deployDir = $script:DeployRoot
$installedSha = $null
try {
    Write-Output "Resolving $($script:RepoOwner)/$($script:RepoName)@$($script:RepoBranch)..."
    $installedSha = Resolve-GitHubBranchSha -Owner $script:RepoOwner -Repo $script:RepoName -Branch $script:RepoBranch
    Write-Output "Resolved commit SHA: $installedSha"
}
catch {
    Write-FatalInstallError -Message "Failed to resolve the current deployment commit." -ErrorRecord $_
}

$zipUrl = "https://github.com/$($script:RepoOwner)/$($script:RepoName)/archive/$installedSha.zip"
$zipFilePath = Join-Path $deployDir "main.zip"

if (Test-Path $deployDir) {
    Remove-Item -Path $deployDir -Recurse -Force
}
New-Item -Path $deployDir -ItemType Directory -Force | Out-Null

try {
    Write-Output "Downloading ZIP file from $zipUrl..."
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFilePath -UseBasicParsing -ErrorAction Stop
    Write-Output "Download complete. Extracting ZIP file..."
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, $deployDir)
    Write-Output "Extraction complete."
}
catch {
    Write-FatalInstallError -Message "Failed to download or extract ZIP file." -ErrorRecord $_
}

Remove-Item -Path $zipFilePath -Force

$extractedDirs = @(Get-ChildItem -Path $deployDir -Directory)
if ($extractedDirs.Count -ne 1) {
    Write-FatalInstallError -Message "Expected exactly one extracted repository directory under $deployDir, found $($extractedDirs.Count)."
}

$sourceDir = $extractedDirs[0].FullName
Write-Output "Moving contents from $sourceDir to $deployDir..."
Get-ChildItem -Path $sourceDir -Force | Move-Item -Destination $deployDir -Force
Remove-Item -Path $sourceDir -Recurse -Force
Write-Output "Contents moved and $sourceDir removed."

$commonPath = Join-Path $deployDir "scripts\_common.ps1"
if (-not (Test-Path $commonPath)) {
    Write-FatalInstallError -Message "Shared helpers not found at $commonPath"
}
. $commonPath

Write-Output ""

$validPurposes = @("radio", "tv", "editorial", "plain")
$validOwnership = @("shared", "personal", "dedicated")
$installerInputNames = @(
    "systemPurpose",
    "systemOwnership",
    "computerName",
    "workgroupName",
    "userPassword",
    "dwAgentCode",
    "dedicatedUserName",
    "personalUserName",
    "installedSha",
    "seedInstalledSha"
)

# Source of truth for prompts; AST parsing only checks this map for drift.
$scriptRequirements = @{
    'applocker'        = @('systemOwnership')
    'apps'             = @('systemPurpose', 'systemOwnership')
    'debloat'          = @()
    'dwservice'        = @('dwAgentCode')
    'hardening'        = @()
    'policies'         = @('systemPurpose', 'systemOwnership')
    'policyupdate'     = @('systemPurpose', 'systemOwnership', 'installedSha', 'seedInstalledSha')
    'power'            = @('systemPurpose', 'systemOwnership')
    'securitybaseline' = @()
    'sounds'           = @()
    'time'             = @()
    'users'            = @('systemPurpose', 'systemOwnership', 'userPassword', 'dedicatedUserName', 'personalUserName')
    'workgroupname'    = @('computerName', 'workgroupName')
}

# Keep -OnlyRun validation and execution tied to the deployed filesystem.
$scriptsDir = Join-Path $deployDir "scripts"
if (-not (Test-Path $scriptsDir)) {
    Write-FatalInstallError -Message "Script directory does not exist: $scriptsDir"
}

$scriptFiles = @(Get-ChildItem -Path $scriptsDir -Filter *.ps1 |
        Where-Object { $_.BaseName -ne "_common" } |
        Sort-Object Name)
$discoveredScriptParams = @{}
$scriptFiles | ForEach-Object {
    # _securitybaseline.ps1 is exposed as securitybaseline.
    $scriptName = $_.BaseName -replace '^_', ''
    $discoveredScriptParams[$scriptName] = Get-ScriptParameterNames -Path $_.FullName
}

$discoveredScriptNames = @($scriptFiles | ForEach-Object { $_.BaseName -replace '^_', '' })
$mappedScriptNames = @($scriptRequirements.Keys)

$missingMappings = @($discoveredScriptNames | Where-Object { $_ -notin $mappedScriptNames })
if ($missingMappings.Count -gt 0) {
    Write-FatalInstallError -Message "Installer requirement map is missing script(s): $($missingMappings -join ', ')"
}

$staleMappings = @($mappedScriptNames | Where-Object { $_ -notin $discoveredScriptNames })
if ($staleMappings.Count -gt 0) {
    Write-FatalInstallError -Message "Installer requirement map contains script(s) that no longer exist: $($staleMappings -join ', ')"
}

# Prevent silently splatting $null for params the installer cannot collect.
$detectedParamCount = @($discoveredScriptParams.Values | ForEach-Object { $_ }).Count
$mappedParamCount = @($scriptRequirements.Values | ForEach-Object { $_ }).Count
$canValidateParamDrift = -not ($mappedParamCount -gt 0 -and $detectedParamCount -eq 0)

if (-not $canValidateParamDrift) {
    Write-Warning "Could not detect script parameters for drift checking; continuing with the explicit installer prompt map."
}

if ($canValidateParamDrift) {
    foreach ($script in $scriptRequirements.Keys) {
        $detectedParams = @($discoveredScriptParams[$script])
        $mappedParams = @($scriptRequirements[$script])

        foreach ($paramName in $detectedParams) {
            if ($paramName -notin $installerInputNames) {
                Write-FatalInstallError -Message "Script '$script' declares parameter -$paramName but install.ps1 does not collect it. Add it to the installer input list."
            }
        }

        $missingParams = @($detectedParams | Where-Object { $_ -notin $mappedParams })
        if ($missingParams.Count -gt 0) {
            Write-FatalInstallError -Message "Script '$script' declares parameter(s) not in the installer requirement map: $($missingParams -join ', ')"
        }

        $staleParams = @($mappedParams | Where-Object { $_ -notin $detectedParams })
        if ($staleParams.Count -gt 0) {
            Write-FatalInstallError -Message "Installer requirement map lists parameter(s) not declared by script '$script': $($staleParams -join ', ')"
        }
    }
}
else {
    foreach ($script in $scriptRequirements.Keys) {
        foreach ($paramName in $scriptRequirements[$script]) {
            if ($paramName -notin $installerInputNames) {
                Write-FatalInstallError -Message "Installer requirement map for '$script' references -$paramName but install.ps1 does not collect it. Add it to the installer input list."
            }
        }
    }
}

if ($OnlyRun) {
    $validScriptNames = @($scriptRequirements.Keys | Sort-Object)
    $unknown = @($OnlyRun | Where-Object { $_ -notin $validScriptNames })
    if ($unknown.Count -gt 0) {
        Write-FatalInstallError -Message "Unknown -OnlyRun value(s): $($unknown -join ', '). Valid scripts: $($validScriptNames -join ', ')"
    }
}

if ($OnlyRun) {
    $requiredParams = @($OnlyRun | ForEach-Object { $scriptRequirements[$_] } | Select-Object -Unique)
}
else {
    $requiredParams = @($scriptRequirements.Values | ForEach-Object { $_ } | Select-Object -Unique)
}

if ('systemPurpose' -in $requiredParams) {
    do {
        Write-Output "System purpose options: $($validPurposes -join ', ')"
        $systemPurpose = (Read-Host -Prompt "Enter the system purpose").ToLower().Trim()
        if ($systemPurpose -notin $validPurposes) {
            Write-Warning "Invalid purpose '$systemPurpose'. Please enter one of: $($validPurposes -join ', ')"
            Write-Output ""
        }
    } while ($systemPurpose -notin $validPurposes)
    Write-Output ""
}

if ('systemOwnership' -in $requiredParams) {
    do {
        Write-Output "System ownership options: $($validOwnership -join ', ')"
        $systemOwnership = (Read-Host -Prompt "Enter the system ownership").ToLower().Trim()
        if ($systemOwnership -notin $validOwnership) {
            Write-Warning "Invalid ownership '$systemOwnership'. Please enter one of: $($validOwnership -join ', ')"
            Write-Output ""
        }
    } while ($systemOwnership -notin $validOwnership)
    Write-Output ""
}

if ('computerName' -in $requiredParams) {
    $computerName = Read-Host -Prompt "Enter the computer name"
}

if ('workgroupName' -in $requiredParams) {
    $workgroupName = Read-Host -Prompt "Enter the workgroup name"
}

if ('dedicatedUserName' -in $requiredParams -and $systemOwnership -eq "dedicated") {
    Write-Output ""
    $createUser = (Read-Host -Prompt "Create a user with auto-login? (y/n)").ToLower().Trim()
    if ($createUser -eq "y" -or $createUser -eq "yes") {
        $dedicatedUserName = Read-Host -Prompt "Enter the username"
    }
}

if ('personalUserName' -in $requiredParams -and $systemOwnership -eq "personal") {
    Write-Output ""
    do {
        $personalUserName = (Read-Host -Prompt "Enter the username for this personal system").Trim()
        if (-not $personalUserName) {
            Write-Warning "Username is required for personal systems."
        }
    } while (-not $personalUserName)
}

# Resolve the account before prompting so the password message names its user.
if ('userPassword' -in $requiredParams) {
    $plannedUser = Resolve-DeploymentUserName -SystemPurpose $systemPurpose -SystemOwnership $systemOwnership `
        -DedicatedUserName $dedicatedUserName -PersonalUserName $personalUserName

    if ($plannedUser.UserName) {
        Write-Output ""
        $userPassword = Read-DeploymentPassword -AccountName $plannedUser.UserName
    }
}

if ('dwAgentCode' -in $requiredParams) {
    Write-Output ""
    Write-Output "DWService agent code (from dwservice.net, leave empty to skip)"
    $dwAgentCode = Read-Host -Prompt "Enter the DWService agent code"
}

Write-Output ""

$allParams = @{
    systemPurpose     = $systemPurpose
    systemOwnership   = $systemOwnership
    userPassword      = $userPassword
    computerName      = $computerName
    workgroupName     = $workgroupName
    dwAgentCode       = $dwAgentCode
    dedicatedUserName = $dedicatedUserName
    personalUserName  = $personalUserName
    installedSha      = $installedSha
    seedInstalledSha  = (-not $OnlyRun) -or (('policyupdate' -in $OnlyRun) -and ('policies' -in $OnlyRun) -and ('applocker' -in $OnlyRun))
}

foreach ($scriptFile in $scriptFiles) {
    $scriptName = $scriptFile.BaseName -replace '^_', ''

    if ($OnlyRun -and $scriptName -notin $OnlyRun) {
        Write-Output "Skipping: $($scriptFile.Name) (not in -OnlyRun list)"
        continue
    }

    Write-Output ""
    Write-Output "=========================================="
    Write-Output "Running: $($scriptFile.Name)"
    Write-Output "=========================================="

    $scriptParams = @{}
    foreach ($paramName in $scriptRequirements[$scriptName]) {
        $scriptParams[$paramName] = $allParams[$paramName]
    }

    try {
        & $scriptFile.FullName @scriptParams
    }
    catch {
        Write-FatalInstallError -Message "Failed to execute script: $($scriptFile.Name)" -ErrorRecord $_
    }
}

Write-Output ""
Write-Output "=========================================="
if ($OnlyRun) {
    Write-Output "Selected scripts completed: $($OnlyRun -join ', ')"
}
else {
    Write-Output "All scripts completed."
}
Write-Output "=========================================="

Complete-Install

#===============================================================
# Windows 11 Baseline for Streekomroep ZuidWest
#===============================================================

param(
    [ValidateSet("radio", "tv", "editorial", "plain")]
    [string]$systemPurpose,

    [ValidateSet("shared", "personal", "dedicated")]
    [string]$systemOwnership,

    [string]$computerName,
    [string]$workgroupName,
    [securestring]$userPassword,
    [string]$dwAgentCode,
    [string]$dedicatedUserName,
    [string]$personalUserName,

    [ValidateSet("debloat", "securitybaseline", "applocker", "apps", "dwservice", "hardening", "policies", "power", "sounds", "time", "updates", "users", "workgroupname")]
    [string[]]$OnlyRun
)

# Function to check for admin rights
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
    (New-Object Security.Principal.WindowsPrincipal $currentUser).IsInRole($adminRole)
}

$script:InstallLogPath = $null

function Initialize-InstallLog {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logDirectories = @(
        (Join-Path $env:ProgramData "ZuidWest\Logs"),
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

    try {
        Read-Host -Prompt $Prompt | Out-Null
    }
    catch {
        Write-Verbose "Could not wait for input: $($_.Exception.Message)"
    }
}

function Write-FatalInstallError {
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [object]$ErrorRecord,

        [int]$ExitCode = 1
    )

    Write-Output ""
    Write-Error $Message
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

# Ensure the script runs with admin rights
if (-not (Test-Admin)) {
    Write-FatalInstallError -Message "This script must be run as an administrator. Exiting..."
}

# Welcome message
Write-Output ""
Write-Output "=========================================="
Write-Output " Windows 11 Baseline - Streekomroep ZuidWest"
Write-Output "=========================================="
Write-Output ""
Write-Output "This script will configure a Windows 11 system with the specified settings."
Write-Output ""

# Download before prompting so we can source _common.ps1 and validate the password input.
$deployDir = "C:\Windows\deploy"
$zipUrl = "https://github.com/oszuidwest/windows11-baseline/archive/refs/heads/main.zip"
$zipFilePath = "$deployDir\main.zip"
$sourceDir = "$deployDir\windows11-baseline-main"

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

if (Test-Path $sourceDir) {
    Write-Output "Moving contents from $sourceDir to $deployDir..."
    Get-ChildItem -Path $sourceDir | Move-Item -Destination $deployDir -Force
    Remove-Item -Path $sourceDir -Recurse -Force
    Write-Output "Contents moved and $sourceDir removed."
}
else {
    Write-FatalInstallError -Message "$sourceDir does not exist. Exiting..."
}

$commonPath = Join-Path $deployDir "scripts\_common.ps1"
if (-not (Test-Path $commonPath)) {
    Write-FatalInstallError -Message "Shared helpers not found at $commonPath"
}
. $commonPath

Write-Output ""

# Valid options
$validPurposes = @("radio", "tv", "editorial", "plain")
$validOwnership = @("shared", "personal", "dedicated")

# Derive requirements from each script's param() block so prompting and splatting stay in sync.
$scriptsDir = Join-Path $deployDir "scripts"
if (-not (Test-Path $scriptsDir)) {
    Write-FatalInstallError -Message "Script directory does not exist: $scriptsDir"
}

$scriptFiles = @(Get-ChildItem -Path $scriptsDir -Filter *.ps1 |
        Where-Object { $_.BaseName -ne "_common" } |
        Sort-Object Name)

$scriptRequirements = @{}
$scriptFiles | ForEach-Object {
    # Public script names strip a leading ordering underscore: _securitybaseline.ps1 -> securitybaseline.
    $scriptName = $_.BaseName -replace '^_', ''
    $scriptRequirements[$scriptName] = Get-ScriptParameterNames -Path $_.FullName
}

# Reverse-drift check: a script param that install.ps1 cannot supply would otherwise splat $null silently.
$installerParams = @(Get-ScriptParameterNames -Path $PSCommandPath | Where-Object { $_ -ne 'OnlyRun' })
foreach ($script in $scriptRequirements.Keys) {
    foreach ($paramName in $scriptRequirements[$script]) {
        if ($paramName -notin $installerParams) {
            Write-FatalInstallError -Message "Script '$script' declares parameter -$paramName but install.ps1 does not collect it. Add it to install.ps1's param() block."
        }
    }
}

# Determine which parameters are required based on -OnlyRun
if ($OnlyRun) {
    $requiredParams = @($OnlyRun | ForEach-Object { $scriptRequirements[$_] } | Select-Object -Unique)
}
else {
    # Full installation: collect requirements for all scripts
    $requiredParams = @($scriptRequirements.Values | ForEach-Object { $_ } | Select-Object -Unique)
}

# Get and validate system purpose (if required and not provided via parameter)
if ('systemPurpose' -in $requiredParams -and -not $systemPurpose) {
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

# Get and validate system ownership (if required and not provided via parameter)
if ('systemOwnership' -in $requiredParams -and -not $systemOwnership) {
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

# Get computer name (if required and not provided via parameter)
if ('computerName' -in $requiredParams -and -not $computerName) {
    $computerName = Read-Host -Prompt "Enter the computer name"
}

# Get workgroup name (if required and not provided via parameter)
if ('workgroupName' -in $requiredParams -and -not $workgroupName) {
    $workgroupName = Read-Host -Prompt "Enter the workgroup name"
}

# For dedicated systems, ask if a user with auto-login should be created
if ('dedicatedUserName' -in $requiredParams -and -not $dedicatedUserName -and $systemOwnership -eq "dedicated") {
    Write-Output ""
    $createUser = (Read-Host -Prompt "Create a user with auto-login? (y/n)").ToLower().Trim()
    if ($createUser -eq "y" -or $createUser -eq "yes") {
        $dedicatedUserName = Read-Host -Prompt "Enter the username"
    }
}

# For personal systems, ask for username (required)
if ('personalUserName' -in $requiredParams -and -not $personalUserName -and $systemOwnership -eq "personal") {
    Write-Output ""
    do {
        $personalUserName = (Read-Host -Prompt "Enter the username for this personal system").Trim()
        if (-not $personalUserName) {
            Write-Warning "Username is required for personal systems."
        }
    } while (-not $personalUserName)
}

# Resolve account name first so the password prompt can enforce the username-substring rule.
$plannedUser = Resolve-DeploymentUserName -SystemPurpose $systemPurpose -SystemOwnership $systemOwnership `
    -DedicatedUserName $dedicatedUserName -PersonalUserName $personalUserName

if ('userPassword' -in $requiredParams -and $plannedUser.UserName) {
    if ($userPassword) {
        try {
            Test-LocalUserPassword -SecurePassword $userPassword -AccountName $plannedUser.UserName
        }
        catch {
            Write-FatalInstallError -Message "Password supplied via -userPassword does not meet policy: $($_.Exception.Message)"
        }
    }
    else {
        Write-Output ""
        $userPassword = Read-DeploymentPassword -AccountName $plannedUser.UserName
    }
}

# Get DWService agent code (if required and not provided via parameter)
if ('dwAgentCode' -in $requiredParams -and -not $dwAgentCode) {
    Write-Output ""
    Write-Output "DWService agent code (from dwservice.net, leave empty to skip)"
    $dwAgentCode = Read-Host -Prompt "Enter the DWService agent code"
}

Write-Output ""

#===============================================================
# Execute all scripts in the scripts directory
#===============================================================

$allParams = @{
    systemPurpose     = $systemPurpose
    systemOwnership   = $systemOwnership
    userPassword      = $userPassword
    computerName      = $computerName
    workgroupName     = $workgroupName
    dwAgentCode       = $dwAgentCode
    dedicatedUserName = $dedicatedUserName
    personalUserName  = $personalUserName
}

foreach ($scriptFile in $scriptFiles) {
    $scriptName = $scriptFile.BaseName -replace '^_', ''

    # Skip scripts not in -OnlyRun list (if specified)
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

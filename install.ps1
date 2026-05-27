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
    [string]$userPassword,
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

function ConvertFrom-SecureStringToPlainText {
    param (
        [Parameter(Mandatory)]
        [securestring]$SecureString
    )

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

# Ensure the script runs with admin rights
if (-not (Test-Admin)) {
    Write-Error "This script must be run as an administrator. Exiting..."
    exit 1
}

# Welcome message
Write-Output ""
Write-Output "=========================================="
Write-Output " Windows 11 Baseline - Streekomroep ZuidWest"
Write-Output "=========================================="
Write-Output ""
Write-Output "This script will configure a Windows 11 system with the specified settings."
Write-Output ""

# Valid options
$validPurposes = @("radio", "tv", "editorial", "plain")
$validOwnership = @("shared", "personal", "dedicated")

# Script requirements mapping - which parameters each script needs
$scriptRequirements = @{
    'debloat'          = @('systemPurpose', 'systemOwnership')
    'securitybaseline' = @()
    'applocker'        = @('systemOwnership')
    'apps'             = @('systemPurpose', 'systemOwnership')
    'dwservice'        = @('dwAgentCode')
    'hardening'        = @()
    'policies'         = @('systemPurpose', 'systemOwnership')
    'power'            = @()
    'sounds'           = @()
    'time'             = @()
    'updates'          = @()
    'users'            = @('systemPurpose', 'systemOwnership', 'userPassword', 'dedicatedUserName', 'personalUserName')
    'workgroupname'    = @('computerName', 'workgroupName')
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

# Get user password (if required and not provided via parameter)
if ('userPassword' -in $requiredParams -and -not $userPassword) {
    $secureUserPassword = Read-Host -Prompt "Enter the user password" -AsSecureString
    $userPassword = ConvertFrom-SecureStringToPlainText -SecureString $secureUserPassword
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

# Get DWService agent code (if required and not provided via parameter)
if ('dwAgentCode' -in $requiredParams -and -not $dwAgentCode) {
    Write-Output ""
    Write-Output "DWService agent code (from dwservice.net, leave empty to skip)"
    $dwAgentCode = Read-Host -Prompt "Enter the DWService agent code"
}

Write-Output ""

# Set deployment directory
$deployDir = "C:\Windows\deploy"
$zipUrl = "https://github.com/oszuidwest/windows11-baseline/archive/refs/heads/main.zip"
$zipFilePath = "$deployDir\main.zip"
$sourceDir = "$deployDir\windows11-baseline-main"

# Clean up and recreate deployment directory
if (Test-Path $deployDir) {
    Remove-Item -Path $deployDir -Recurse -Force
}
New-Item -Path $deployDir -ItemType Directory -Force

# Download and extract ZIP file
try {
    Write-Output "Downloading ZIP file from $zipUrl..."
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFilePath -UseBasicParsing
    Write-Output "Download complete. Extracting ZIP file..."
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, $deployDir)
    Write-Output "Extraction complete."
}
catch {
    Write-Error "Failed to download or extract ZIP file: $_"
    exit 1
}

# Clean up the downloaded ZIP file
Remove-Item -Path $zipFilePath -Force

# Move extracted contents to root of deployDir
if (Test-Path $sourceDir) {
    Write-Output "Moving contents from $sourceDir to $deployDir..."
    Get-ChildItem -Path $sourceDir | Move-Item -Destination $deployDir -Force
    Remove-Item -Path $sourceDir -Recurse -Force
    Write-Output "Contents moved and $sourceDir removed."
}
else {
    Write-Error "$sourceDir does not exist. Exiting..."
    exit 1
}

#===============================================================
# Execute all scripts in the scripts directory
#===============================================================

$scriptsDir = "$deployDir\scripts"

# Check if the scripts directory exists
if (Test-Path $scriptsDir) {
    # Get executable .ps1 files in the scripts directory (sorted alphabetically)
    $scriptFiles = Get-ChildItem -Path $scriptsDir -Filter *.ps1 |
        Where-Object { $_.BaseName -ne "_common" } |
        Sort-Object Name

    foreach ($scriptFile in $scriptFiles) {
        # Get script name without extension and underscore prefix (e.g., "_debloat.ps1" -> "debloat")
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

        $scriptParams = @{}
        if ($scriptRequirements.ContainsKey($scriptName)) {
            foreach ($paramName in $scriptRequirements[$scriptName]) {
                $scriptParams[$paramName] = $allParams[$paramName]
            }
        }
        else {
            $scriptParams = $allParams
        }

        try {
            & $scriptFile.FullName @scriptParams
        }
        catch {
            Write-Error "Failed to execute script: $($scriptFile.Name) - Error: $_"
            exit 1
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
}
else {
    Write-Error "Script directory does not exist: $scriptsDir"
    exit 1
}

# Prevent the script from closing immediately
Read-Host -Prompt "Press Enter to exit..."

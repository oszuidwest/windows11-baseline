#===============================================================
# Windows 11 Baseline for Streekomroep ZuidWest
#===============================================================

# Function to check for admin rights
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
    (New-Object Security.Principal.WindowsPrincipal $currentUser).IsInRole($adminRole)
}

# Ensure the script runs with admin rights
if (-not (Test-Admin)) {
    Write-Error "This script must be run as an administrator. Exiting..."
    exit
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

# Get and validate system purpose
do {
    Write-Output "System purpose options: $($validPurposes -join ', ')"
    $systemPurpose = (Read-Host -Prompt "Enter the system purpose").ToLower().Trim()
    if ($systemPurpose -notin $validPurposes) {
        Write-Warning "Invalid purpose '$systemPurpose'. Please enter one of: $($validPurposes -join ', ')"
        Write-Output ""
    }
} while ($systemPurpose -notin $validPurposes)

Write-Output ""

# Get and validate system ownership
do {
    Write-Output "System ownership options: $($validOwnership -join ', ')"
    $systemOwnership = (Read-Host -Prompt "Enter the system ownership").ToLower().Trim()
    if ($systemOwnership -notin $validOwnership) {
        Write-Warning "Invalid ownership '$systemOwnership'. Please enter one of: $($validOwnership -join ', ')"
        Write-Output ""
    }
} while ($systemOwnership -notin $validOwnership)

Write-Output ""
$computerName = Read-Host -Prompt "Enter the computer name"
$workgroupName = Read-Host -Prompt "Enter the workgroup name"
$userPassword = Read-Host -Prompt "Enter the user password"

# For dedicated systems, ask if a user with auto-login should be created
$dedicatedUserName = ""
if ($systemOwnership -eq "dedicated") {
    Write-Output ""
    $createUser = (Read-Host -Prompt "Create a user with auto-login? (y/n)").ToLower().Trim()
    if ($createUser -eq "y" -or $createUser -eq "yes") {
        $dedicatedUserName = Read-Host -Prompt "Enter the username"
    }
}

Write-Output ""
Write-Output "DWService agent code (from dwservice.net, leave empty to skip)"
$dwAgentCode = Read-Host -Prompt "Enter the DWService agent code"

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
    Write-Error "Failed to download or extract ZIP file. Exiting..."
    exit
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
    exit
}

#===============================================================
# Execute all scripts in the scripts directory
#===============================================================

$scriptsDir = "$deployDir\scripts"

# Check if the scripts directory exists
if (Test-Path $scriptsDir) {
    # Get all .ps1 files in the scripts directory (sorted alphabetically)
    $scriptFiles = Get-ChildItem -Path $scriptsDir -Filter *.ps1 | Sort-Object Name

    foreach ($scriptFile in $scriptFiles) {
        Write-Output ""
        Write-Output "=========================================="
        Write-Output "Running: $($scriptFile.Name)"
        Write-Output "=========================================="

        try {
            & $scriptFile.FullName -systemPurpose $systemPurpose -systemOwnership $systemOwnership -userPassword $userPassword -computerName $computerName -workgroupName $workgroupName -dwAgentCode $dwAgentCode -dedicatedUserName $dedicatedUserName
        }
        catch {
            Write-Error "Failed to execute script: $($scriptFile.Name) - Error: $_"
        }
    }

    Write-Output ""
    Write-Output "=========================================="
    Write-Output "All scripts completed."
    Write-Output "=========================================="
}
else {
    Write-Error "Script directory does not exist: $scriptsDir"
}

# Prevent the script from closing immediately
Read-Host -Prompt "Press Enter to exit..."

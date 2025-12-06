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

# Get user inputs
$systemPurpose = Read-Host -Prompt "Enter the system purpose:"
$systemOwnership = Read-Host -Prompt "Enter the system ownership:"
$userPassword = Read-Host -Prompt "Enter the user password:"
$computerName = Read-Host -Prompt "Enter the computer name:"
$workgroupName = Read-Host -Prompt "Enter the workgroup name:"

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
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFilePath
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
    Write-Output "Found script directory: $scriptsDir"

    # Get all .ps1 files in the scripts directory
    $scriptFiles = Get-ChildItem -Path $scriptsDir -Filter *.ps1

    foreach ($scriptFile in $scriptFiles) {
        # Display a message before executing each script
        Write-Output "Executing script: $($scriptFile.FullName)"

        try {
            # Construct the argument list
            $arguments = @(
                "-File `"$($scriptFile.FullName)`"",
                "-systemPurpose `"$systemPurpose`"",
                "-systemOwnership `"$systemOwnership`"",
                "-userPassword `"$userPassword`"",
                "-computerName `"$computerName`"",
                "-workgroupName `"$workgroupName`""
            )

            # Join the arguments into a single string
            $argumentString = $arguments -join ' '

            # Execute the script as an administrator in a new process and window
            Start-Process -FilePath "powershell.exe" -ArgumentList $argumentString -Verb RunAs -WindowStyle Normal

            Write-Output "Successfully executed script: $($scriptFile.FullName)"
        }
        catch {
            Write-Error "Failed to execute script: $($scriptFile.FullName) - Error: $_"
        }
    }

    Write-Output "All scripts spawned."
}
else {
    Write-Error "Script directory does not exist: $scriptsDir"
}

# Prevent the script from closing immediately
Read-Host -Prompt "Press Enter to exit..."

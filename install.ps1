#===============================================================
# Windows 11 Baseline for Streekomroep ZuidWest
#===============================================================

# Function to prompt for user input
function Get-UserInput {
    param (
        [string]$PromptMessage
    )
    return Read-Host -Prompt $PromptMessage
}

# Function to check for admin rights
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal $currentUser).IsInRole($adminRole)
    return $isAdmin
}

# Check if running as admin
if (-not (Test-Admin)) {
    Write-Error "This script must be run as an administrator. Exiting..."
    exit
}

# Prompt for system purpose
$systemPurpose = Get-UserInput -PromptMessage "Enter the system purpose:"

# Prompt for system ownership
$systemOwnership = Get-UserInput -PromptMessage "Enter the system ownership:"

# Prompt for user password
$userPassword = Get-UserInput -PromptMessage "Enter the user password:"

# Prompt for computer name
$computerName = Get-UserInput -PromptMessage "Enter the computer name:"

# Prompt for workgroup name
$workgroupName = Get-UserInput -PromptMessage "Enter the workgroup name:"

#===============================================================
# Cleanup directory
#===============================================================

$deployDir = "C:\Windows\deploy"

# Recreate the directory forcefully
if (Test-Path $deployDir) {
    Remove-Item -Path $deployDir -Recurse -Force
}
New-Item -Path $deployDir -ItemType Directory -Force

#===============================================================
# Call all sub-scripts with admin rights and bypass execution policy
#===============================================================

$scriptsDir = "C:\Windows\deploy\scripts"

if (Test-Path $scriptsDir) {
    # Get all .ps1 files in the directory
    $scriptFiles = Get-ChildItem -Path $scriptsDir -Filter *.ps1

    foreach ($scriptFile in $scriptFiles) {
        Write-Output "Executing script: $($scriptFile.FullName)"
        try {
            $arguments = @(
                "-ExecutionPolicy Bypass"
                "-File `"$($scriptFile.FullName)`""
                "-systemPurpose `"$systemPurpose`""
                "-systemOwnership `"$systemOwnership`""
                "-userPassword `"$userPassword`""
                "-computerName `"$computerName`""
                "-workgroupName `"$workgroupName`""
            )
            Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -Wait -NoNewWindow -Verb RunAs
            Write-Output "Successfully executed: $($scriptFile.FullName)"
        }
        catch {
            Write-Output "Failed to execute: $($scriptFile.FullName) - Error: $_"
        }
    }
}
else {
    Write-Output "Script directory does not exist: $scriptsDir"
}

Write-Output "Script execution completed."

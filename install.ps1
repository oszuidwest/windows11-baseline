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
$purpose = Get-UserInput -PromptMessage "Enter the system purpose:"
[System.Environment]::SetEnvironmentVariable("_deploy_purpose", $purpose, [System.EnvironmentVariableTarget]::Machine)

# Prompt for system ownership
$ownership = Get-UserInput -PromptMessage "Enter the system ownership:"
[System.Environment]::SetEnvironmentVariable("_deploy_ownership", $ownership, [System.EnvironmentVariableTarget]::Machine)

# Prompt for user password
$deploy_user_password = Get-UserInput -PromptMessage "Enter the user password:"
[System.Environment]::SetEnvironmentVariable("_deploy_user_password", $deploy_user_password, [System.EnvironmentVariableTarget]::Machine)

# Prompt for computer name
$deploy_computer_name = Get-UserInput -PromptMessage "Enter the computer name:"
[System.Environment]::SetEnvironmentVariable("_deploy_computer_name", $deploy_computer_name, [System.EnvironmentVariableTarget]::Machine)

# Prompt for workgroup
$workgroup = Get-UserInput -PromptMessage "Enter the workgroup name:"
[System.Environment]::SetEnvironmentVariable("_deploy_workgroup", $workgroup, [System.EnvironmentVariableTarget]::Machine)

#===============================================================
# Cleanup directory
#===============================================================

$deployDirectory = "C:\Windows\deploy"

# Recreate the directory forcefully
if (Test-Path $deployDirectory) {
    Remove-Item -Path $deployDirectory -Recurse -Force
}
New-Item -Path $deployDirectory -ItemType Directory -Force

#===============================================================
# Call all sub-scripts with admin rights and bypass execution policy
#===============================================================

$scriptDirectory = "C:\Windows\deploy\scripts"

if (Test-Path $scriptDirectory) {
    # Get all .ps1 files in the directory
    $scriptFiles = Get-ChildItem -Path $scriptDirectory -Filter *.ps1

    foreach ($scriptFile in $scriptFiles) {
        Write-Output "Executing script: $($scriptFile.FullName)"
        try {
            $arguments = "-ExecutionPolicy Bypass -File `"$($scriptFile.FullName)`" -purpose `"$purpose`" -ownership `"$ownership`" -password `"$deploy_user_password`" -computername `"$deploy_computer_name`" -workgroup `"$workgroup`""
            Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -Wait -NoNewWindow -Verb RunAs
            Write-Output "Successfully executed: $($scriptFile.FullName)"
        }
        catch {
            Write-Output "Failed to execute: $($scriptFile.FullName) - Error: $_"
        }
    }
}
else {
    Write-Output "Script directory does not exist: $scriptDirectory"
}

Write-Output "Script execution completed."


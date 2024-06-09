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
# Call sub-scripts
#===============================================================

# TODO: Implement a loop that calls all the script
$installScriptPath = "C:\windows\deploy\apps.ps1"
$arguments = "-purpose `"$purpose`" -ownership `"$ownership`""
Start-Process -FilePath "powershell.exe" -ArgumentList "-File `"$installScriptPath`" $arguments" -Wait -NoNewWindow

Write-Output "Script execution completed."
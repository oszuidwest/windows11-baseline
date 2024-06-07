#===============================================================
# Set variables
#===============================================================

# Prompt for system type and purpose

# Prompt for user password
$deploy_user_password = Read-Host -Prompt "Geef het wachtwoord voor de gebruiker in"
[System.Environment]::SetEnvironmentVariable("_deploy_user_password", $deploy_user_password, [System.EnvironmentVariableTarget]::Machine)

# Prompt for computer name
$deploy_computer_name = Read-Host -Prompt "Vul computernaam in"
[System.Environment]::SetEnvironmentVariable("_deploy_computer_name", $deploy_computer_name, [System.EnvironmentVariableTarget]::Machine)

#===============================================================
# Cleanup directory
#===============================================================

$deployDirectory = "C:\Windows\deploy"

# Recreate the directory forcefully
New-Item -Path $deployDirectory -ItemType Directory -Force
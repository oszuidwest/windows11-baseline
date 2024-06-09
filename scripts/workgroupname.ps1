# Define script parameters
param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName
)

# Fetch current system properties
$currentComputerName = (Get-CimInstance -ClassName Win32_ComputerSystem).Name
$currentWorkgroup = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain

# Check and update the computer name if necessary
if ($currentComputerName -ne $computerName) {
    Write-Output "Changing computer name from $currentComputerName to $computerName..."
    Rename-Computer -NewName $computerName -Force
}
else {
    Write-Output "Computer name is already $computerName. No change needed."
}

# Check and update the workgroup if necessary
if ($currentWorkgroup -ne $workgroupName) {
    Write-Output "Changing workgroup from $currentWorkgroup to $workgroupName..."
    Add-Computer -WorkGroupName $workgroupName
}
else {
    Write-Output "Workgroup is already $workgroupName. No change needed."
}

# Prevent the script from closing immediately
Read-Host -Prompt "Press Enter to exit..."

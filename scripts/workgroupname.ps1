# Define script parameters
param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [securestring]$userPassword,
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

# Check and update the workgroup if necessary
if ($currentWorkgroup -ne $workgroup) {
    Write-Output "Changing workgroup from $currentWorkgroup to $workgroupName..."
    Add-Computer -WorkGroupName $workgroupName
}

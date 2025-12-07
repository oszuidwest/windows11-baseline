# Define script parameters
param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName,
    [string]$dwAgentCode
)

Write-Output "Configuring computer name and workgroup..."

# Fetch current system properties
$currentComputerName = (Get-CimInstance -ClassName Win32_ComputerSystem).Name
$currentWorkgroup = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain

# Check and update the computer name if necessary
if ($currentComputerName -ne $computerName) {
    Write-Output "Changing computer name from $currentComputerName to $computerName..."
    try {
        Rename-Computer -NewName $computerName -Force -ErrorAction Stop
        Write-Output "  Computer name changed successfully."
    }
    catch {
        Write-Error "Failed to rename computer: $_"
    }
}
else {
    Write-Output "Computer name is already $computerName. No change needed."
}

# Check and update the workgroup if necessary
if ($currentWorkgroup -ne $workgroupName) {
    Write-Output "Changing workgroup from $currentWorkgroup to $workgroupName..."
    try {
        Add-Computer -WorkGroupName $workgroupName -ErrorAction Stop
        Write-Output "  Workgroup changed successfully."
    }
    catch {
        Write-Error "Failed to change workgroup: $_"
    }
}
else {
    Write-Output "Workgroup is already $workgroupName. No change needed."
}

Write-Output "Computer name and workgroup configured."

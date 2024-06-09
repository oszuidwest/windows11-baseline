param (
    [string]$purpose,
    [string]$ownership,
    [string]$password,
    [string]$computername,
    [string]$workgroup
)

# Fetch current system properties
$currentComputerName = (Get-CimInstance -ClassName Win32_ComputerSystem).Name
$currentWorkgroup = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain

# Check and update the computer name if necessary
if ($currentComputerName -ne $computername) {
    Write-Output "Changing computer name from $currentComputerName to $computername..."
    Rename-Computer -NewName $computername -Force
}

# Check and update the workgroup if necessary
if ($currentWorkgroup -ne $workgroup) {
    Write-Output "Changing workgroup from $currentWorkgroup to $workgroup..."
    Add-Computer -WorkGroupName $workgroup
}

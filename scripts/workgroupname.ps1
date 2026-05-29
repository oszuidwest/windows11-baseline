param (
    [string]$computerName,
    [string]$workgroupName
)

Write-Output "Configuring computer name and workgroup..."

$currentComputerName = (Get-CimInstance -ClassName Win32_ComputerSystem).Name
$currentWorkgroup = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain

if ($currentComputerName -ne $computerName) {
    Write-Output "Changing computer name from $currentComputerName to $computerName..."
    try {
        Rename-Computer -NewName $computerName -Force -ErrorAction Stop
        Write-Output "  Computer name changed successfully."
    }
    catch {
        throw "Failed to rename computer: $($_.Exception.Message)"
    }
}
else {
    Write-Output "Computer name is already $computerName. No change needed."
}

if ($currentWorkgroup -ne $workgroupName) {
    Write-Output "Changing workgroup from $currentWorkgroup to $workgroupName..."
    try {
        Add-Computer -WorkGroupName $workgroupName -ErrorAction Stop
        Write-Output "  Workgroup changed successfully."
    }
    catch {
        throw "Failed to change workgroup: $($_.Exception.Message)"
    }
}
else {
    Write-Output "Workgroup is already $workgroupName. No change needed."
}

Write-Output "Computer name and workgroup configured."

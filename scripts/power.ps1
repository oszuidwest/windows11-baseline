param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName,
    [string]$dwAgentCode
)

Write-Output "Configuring power settings..."

$failed = $false

# Set monitor timeout (30 min AC, 30 min DC)
Write-Output "  Monitor timeout: 30 min"
powercfg /change monitor-timeout-ac 30 2>&1 | Out-Null
powercfg /change monitor-timeout-dc 30 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { $failed = $true }

# Disable disk timeout (not needed for SSDs)
Write-Output "  Disk timeout: disabled"
powercfg /change disk-timeout-ac 0 2>&1 | Out-Null
powercfg /change disk-timeout-dc 0 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { $failed = $true }

# Set standby timeout (never on AC, 60 min on DC)
Write-Output "  Standby: never (AC), 60 min (DC)"
powercfg /change standby-timeout-ac 0 2>&1 | Out-Null
powercfg /change standby-timeout-dc 60 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { $failed = $true }

# Disable hibernate
Write-Output "  Hibernate: disabled"
powercfg /change hibernate-timeout-ac 0 2>&1 | Out-Null
powercfg /change hibernate-timeout-dc 0 2>&1 | Out-Null
powercfg /hibernate off 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { $failed = $true }

if ($failed) {
    Write-Warning "Some power settings may not have been applied."
}

Write-Output "Power settings configured."
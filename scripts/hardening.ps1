# Define script parameters
param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName,
    [string]$dwAgentCode,
    [string]$dedicatedUserName
)

<#
This script applies additional security hardening.
Runs for all system purposes and ownership types.
#>

Write-Output "Applying security hardening..."

# Disable Remote Registry service (attack surface reduction)
Write-Output "Disabling Remote Registry service..."
try {
    Stop-Service -Name RemoteRegistry -Force -ErrorAction SilentlyContinue
    Set-Service -Name RemoteRegistry -StartupType Disabled -ErrorAction Stop
    Write-Output "  Remote Registry service disabled."
}
catch {
    Write-Warning "  Failed to disable Remote Registry: $_"
}

Write-Output "Security hardening complete."

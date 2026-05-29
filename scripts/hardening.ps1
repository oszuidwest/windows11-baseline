param()

<#
This script applies additional security hardening.
Runs for all system purposes and ownership types.
#>

Write-Output "Applying security hardening..."

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

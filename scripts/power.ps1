param (
    [string]$systemPurpose,
    [string]$systemOwnership
)

. (Join-Path $PSScriptRoot "_common.ps1")

Write-Output "Configuring power settings..."

function Set-PowerTimeout {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param (
        [string]$Setting,
        [int]$AcValue,
        [int]$DcValue
    )

    if (-not $PSCmdlet.ShouldProcess($Setting, "Set AC/DC power timeout")) {
        return $true
    }

    try {
        Invoke-NativeCommand -FilePath "powercfg" `
            -Arguments @("/change", "$Setting-ac", $AcValue) `
            -FailureMessage "Failed to set $Setting AC timeout" | Out-Null
        Invoke-NativeCommand -FilePath "powercfg" `
            -Arguments @("/change", "$Setting-dc", $DcValue) `
            -FailureMessage "Failed to set $Setting DC timeout" | Out-Null
        return $true
    }
    catch {
        Write-Warning $_.Exception.Message
        return $false
    }
}

$success = $true

Write-Output "  Monitor timeout: 30 min"
if (-not (Set-PowerTimeout -Setting "monitor-timeout" -AcValue 30 -DcValue 30)) { $success = $false }

Write-Output "  Disk timeout: disabled"
if (-not (Set-PowerTimeout -Setting "disk-timeout" -AcValue 0 -DcValue 0)) { $success = $false }

Write-Output "  Standby: never (AC), 60 min (DC)"
if (-not (Set-PowerTimeout -Setting "standby-timeout" -AcValue 0 -DcValue 60)) { $success = $false }

Write-Output "  Hibernate: disabled"
if (-not (Set-PowerTimeout -Setting "hibernate-timeout" -AcValue 0 -DcValue 0)) { $success = $false }
Invoke-NativeCommand -FilePath "powercfg" `
    -Arguments @("/hibernate", "off") `
    -FailureMessage "Failed to disable hibernate" | Out-Null

if (-not $success) {
    Write-Warning "Some power settings may not have been applied."
}

# Disable NIC power management for AoIP reliability (radio, tv, dedicated)
if ($systemPurpose -in @("radio", "tv") -or $systemOwnership -eq "dedicated") {
    Write-Output "  Disabling NIC power management for AoIP..."
    Get-NetAdapter -Physical | ForEach-Object {
        $adapterName = $_.Name

        # Disable adapter power saving
        Set-NetAdapterPowerManagement -Name $adapterName -WakeOnMagicPacket Disabled -WakeOnPattern Disabled -DeviceSleepOnDisconnect Disabled -ErrorAction SilentlyContinue

        # Disable Energy Efficient Ethernet (prevents latency spikes)
        Set-NetAdapterAdvancedProperty -Name $adapterName -RegistryKeyword "*EEE" -RegistryValue 0 -ErrorAction SilentlyContinue

        Write-Output "    $adapterName configured"
    }
}

Write-Output "Power settings configured."

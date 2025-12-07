param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName,
    [string]$dwAgentCode
)

<#
.SYNOPSIS
    Disables Windows system sounds for studio environments.

.DESCRIPTION
    This script disables all Windows system sounds by modifying the Default User
    profile. This ensures all new users will have sounds disabled, which is
    essential for radio and TV studio workstations to prevent unwanted audio
    during broadcasts.

    Only runs for 'radio' and 'tv' system purposes.
#>

# Only apply to radio and tv systems
$studioPurposes = @("radio", "tv")
if ($systemPurpose.ToLower() -notin $studioPurposes) {
    Write-Output "Skipping sound configuration (not a studio system)."
    exit 0
}

Write-Output "Disabling Windows system sounds for studio environment..."

# Path to Default User profile
$defaultUserHive = "C:\Users\Default\NTUSER.DAT"
$tempKey = "HKU\DefaultUser"

# Load the Default User registry hive
Write-Output "Loading Default User registry hive..."
$result = reg load $tempKey $defaultUserHive 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to load Default User hive: $result"
    exit 1
}

try {
    $errorCount = 0

    # Set sound scheme to None
    $schemePath = "Registry::$tempKey\AppEvents\Schemes"
    if (Test-Path $schemePath) {
        try {
            Set-ItemProperty -Path $schemePath -Name "(Default)" -Value ".None" -ErrorAction Stop
            Write-Output "  Set sound scheme to None"
        }
        catch {
            Write-Warning "  Failed to set sound scheme: $_"
            $errorCount++
        }
    }

    # Clear all individual sound events
    $basePath = "Registry::$tempKey\AppEvents\Schemes\Apps"
    if (Test-Path $basePath) {
        $apps = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
        $clearedCount = 0

        foreach ($app in $apps) {
            $events = Get-ChildItem -Path $app.PSPath -ErrorAction SilentlyContinue

            foreach ($event in $events) {
                $currentPath = Join-Path $event.PSPath ".Current"
                if (Test-Path $currentPath) {
                    try {
                        Set-ItemProperty -Path $currentPath -Name "(Default)" -Value "" -ErrorAction Stop
                        $clearedCount++
                    }
                    catch {
                        $errorCount++
                    }
                }
            }
        }
        Write-Output "  Cleared $clearedCount sound event associations"
    }

    if ($errorCount -gt 0) {
        Write-Warning "Completed with $errorCount errors."
    }
    else {
        Write-Output "System sounds disabled successfully."
    }
}
finally {
    # Force release of all registry handles
    [gc]::Collect()
    [gc]::WaitForPendingFinalizers()
    [gc]::Collect()
    Start-Sleep -Seconds 1

    # Try to unload with retries
    $maxRetries = 5
    $retryCount = 0
    $unloaded = $false

    while (-not $unloaded -and $retryCount -lt $maxRetries) {
        $retryCount++
        $result = reg unload $tempKey 2>&1
        if ($LASTEXITCODE -eq 0) {
            $unloaded = $true
            Write-Output "Default User registry hive unloaded."
        }
        else {
            if ($retryCount -lt $maxRetries) {
                Write-Output "  Retry $retryCount/$maxRetries - waiting for handles to release..."
                Start-Sleep -Seconds 2
                [gc]::Collect()
                [gc]::WaitForPendingFinalizers()
            }
        }
    }

    if (-not $unloaded) {
        Write-Warning "Could not unload registry hive. It will be released on reboot."
    }
}

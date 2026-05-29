param()

<#
.SYNOPSIS
    Disables Windows system sounds.

.DESCRIPTION
    Updates the Default User profile so new users start with the None sound scheme.
#>

. (Join-Path $PSScriptRoot "_common.ps1")

Write-Output "Disabling Windows system sounds..."

$defaultUserHive = "C:\Users\Default\NTUSER.DAT"
$tempKey = "HKU\DefaultUser"

Write-Output "Loading Default User registry hive..."
try {
    Invoke-NativeCommand -FilePath "reg.exe" `
        -Arguments @("load", $tempKey, $defaultUserHive) `
        -FailureMessage "Failed to load Default User hive" | Out-Null
}
catch {
    throw $_.Exception.Message
}

try {
    $errorCount = 0

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
    # Release registry handles before unloading the hive.
    [gc]::Collect()
    [gc]::WaitForPendingFinalizers()
    [gc]::Collect()
    Start-Sleep -Seconds 1

    $maxRetries = 5
    $retryCount = 0
    $unloaded = $false

    while (-not $unloaded -and $retryCount -lt $maxRetries) {
        $retryCount++
        try {
            Invoke-NativeCommand -FilePath "reg.exe" `
                -Arguments @("unload", $tempKey) `
                -FailureMessage "Failed to unload Default User hive" | Out-Null
            $unloaded = $true
            Write-Output "Default User registry hive unloaded."
        }
        catch {
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

param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName
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
    # Set sound scheme to None
    $schemePath = "Registry::$tempKey\AppEvents\Schemes"
    if (Test-Path $schemePath) {
        Set-ItemProperty -Path $schemePath -Name "(Default)" -Value ".None" -ErrorAction SilentlyContinue
        Write-Output "  Set sound scheme to None"
    }

    # Clear all individual sound events
    $basePath = "Registry::$tempKey\AppEvents\Schemes\Apps"
    if (Test-Path $basePath) {
        $apps = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue

        foreach ($app in $apps) {
            $events = Get-ChildItem -Path $app.PSPath -ErrorAction SilentlyContinue

            foreach ($event in $events) {
                $currentPath = Join-Path $event.PSPath ".Current"
                if (Test-Path $currentPath) {
                    Set-ItemProperty -Path $currentPath -Name "(Default)" -Value "" -ErrorAction SilentlyContinue
                }
            }
        }
        Write-Output "  Cleared all sound event associations"
    }

    Write-Output "System sounds disabled successfully."
}
finally {
    # Unload the registry hive
    [gc]::Collect()
    Start-Sleep -Milliseconds 500
    $result = reg unload $tempKey 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to unload Default User hive: $result"
    }
    else {
        Write-Output "Default User registry hive unloaded."
    }
}

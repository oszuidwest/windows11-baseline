# Define script parameters
param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName
)

<#
This script installs applications based on the specified purpose and ownership type.
'systemPurpose' should be "radio", "tv", "editorial", or "plain".
'systemOwnership' should be "shared", "personal", or "dedicated".
Both parameters are mandatory.
#>

# Application scripts by purpose
$appScripts = @{
    "radio"     = "app-audacity.ps1", "app-libreoffice.ps1", "app-thunderbird.ps1", "app-vlc.ps1"
    "tv"        = "app-creativecloud.ps1", "app-libreoffice.ps1", "app-vlc.ps1"
    "editorial" = "app-audacity.ps1", "app-libreoffice.ps1", "app-msteams.ps1", "app-pintra.ps1", "app-vlc.ps1"
    "plain"     = @()
}

# Function to install applications
function Install-Apps {
    param (
        [string]$purpose,
        [string]$ownership
    )
    $purpose = $purpose.ToLower()
    $scripts = $appScripts[$purpose]
    if ($scripts.Count -eq 0) {
        Write-Output "No apps to install for '$purpose'."
        return
    }

    $baseDir = "C:\Windows\deploy\installers"
    foreach ($script in $scripts) {
        $scriptPath = Join-Path $baseDir $script
        if (Test-Path $scriptPath) {
            Write-Output "Running $script for $ownership ownership..."
            Start-Process -FilePath "powershell.exe" -ArgumentList "-File `"$scriptPath`"" -Verb RunAs -Wait
        }
        else {
            Write-Warning "Script $scriptPath not found."
        }
    }
}

# Main execution
if (-not $systemPurpose -or -not $systemOwnership) {
    Write-Error "Both 'systemPurpose' and 'systemOwnership' parameters must be provided."
    exit
}

$systemPurpose = $systemPurpose.ToLower()
if (-not $appScripts.ContainsKey($systemPurpose)) {
    Write-Error "Invalid 'systemPurpose': $systemPurpose. Exiting."
    exit
}

Write-Output "Installing apps for '$systemPurpose' with '$systemOwnership' ownership..."
Install-Apps -purpose $systemPurpose -ownership $systemOwnership
Write-Output "Installation complete."

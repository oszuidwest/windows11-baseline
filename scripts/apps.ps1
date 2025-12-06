# Define script parameters
param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName
)

<#
This script installs applications based on the specified purpose.
'systemPurpose' should be "radio", "tv", "editorial", or "plain".
#>

# Winget package IDs
$appDefinitions = @{
    "audacity"       = "Audacity.Audacity"
    "creativecloud"  = "Adobe.CreativeCloud"
    "libreoffice"    = "TheDocumentFoundation.LibreOffice"
    "msteams"        = "Microsoft.Teams"
    "pinta"          = "Pinta.Pinta"
    "thunderbird"    = "Mozilla.Thunderbird"
    "vlc"            = "VideoLAN.VLC"
}

# Applications by purpose
$appsByPurpose = @{
    "radio"     = @("audacity", "libreoffice", "thunderbird", "vlc")
    "tv"        = @("creativecloud", "libreoffice", "vlc")
    "editorial" = @("audacity", "libreoffice", "msteams", "pinta", "vlc")
    "plain"     = @()
}

# Validate parameters
if (-not $systemPurpose) {
    Write-Error "'systemPurpose' parameter must be provided."
    exit 1
}

$systemPurpose = $systemPurpose.ToLower()
if (-not $appsByPurpose.ContainsKey($systemPurpose)) {
    Write-Error "Invalid 'systemPurpose': $systemPurpose. Valid values: radio, tv, editorial, plain"
    exit 1
}

# Get apps for this purpose
$apps = $appsByPurpose[$systemPurpose]

if ($apps.Count -eq 0) {
    Write-Output "No apps to install for '$systemPurpose'."
    exit 0
}

Write-Output "Installing apps for '$systemPurpose'..."

foreach ($app in $apps) {
    $packageId = $appDefinitions[$app]

    if (-not $packageId) {
        Write-Warning "Skipping '$app': not defined"
        continue
    }

    Write-Output "Installing $app ($packageId)..."
    $wingetArgs = "install --id=$packageId -e --silent --accept-package-agreements --accept-source-agreements"
    $process = Start-Process -FilePath "winget" -ArgumentList $wingetArgs -NoNewWindow -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        Write-Warning "Failed to install $app (exit code: $($process.ExitCode))"
    }
}

Write-Output "Installation complete."

# Prevent the script from closing immediately
Read-Host -Prompt "Press Enter to exit..."

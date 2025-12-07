# Define script parameters
param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName,
    [string]$dwAgentCode
)

<#
This script installs applications based on the specified purpose.
'systemPurpose' should be "radio", "tv", "editorial", or "plain".
#>

# Winget package IDs
$appDefinitions = @{
    "audacity"      = "Audacity.Audacity"
    "creativecloud" = "Adobe.CreativeCloud"
    "libreoffice"   = "TheDocumentFoundation.LibreOffice"
    "msteams"       = "Microsoft.Teams"
    "pinta"         = "Pinta.Pinta"
    "thunderbird"   = "Mozilla.Thunderbird"
    "vlc"           = "VideoLAN.VLC"
}

# Applications by purpose
$appsByPurpose = @{
    "radio"     = @("audacity", "libreoffice", "thunderbird", "vlc")
    "tv"        = @("creativecloud", "libreoffice", "vlc")
    "editorial" = @("audacity", "msteams", "pinta", "vlc")
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

# Install winget if not available (required for LTSC which has no Microsoft Store)
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Output "Winget not found. Installing for LTSC..."

    $tempDir = Join-Path $env:TEMP "winget-install"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        # Install VCLibs dependency
        Write-Output "  Installing VCLibs dependency..."
        $vcLibsPath = Join-Path $tempDir "vclibs.appx"
        Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile $vcLibsPath -UseBasicParsing
        Add-AppxPackage -Path $vcLibsPath -ErrorAction Stop

        # Install UI.Xaml dependency
        Write-Output "  Installing UI.Xaml dependency..."
        $xamlPath = Join-Path $tempDir "xaml.zip"
        Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6" -OutFile $xamlPath -UseBasicParsing
        Expand-Archive -Path $xamlPath -DestinationPath (Join-Path $tempDir "xaml") -Force
        Add-AppxPackage -Path (Join-Path $tempDir "xaml\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.8.appx") -ErrorAction Stop

        # Get latest winget release from GitHub
        Write-Output "  Downloading Winget from GitHub..."
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing
        $msixUrl = ($release.assets | Where-Object { $_.name -match "\.msixbundle$" }).browser_download_url
        $licenseUrl = ($release.assets | Where-Object { $_.name -match "License.*\.xml$" }).browser_download_url

        $msixPath = Join-Path $tempDir "winget.msixbundle"
        $licensePath = Join-Path $tempDir "license.xml"

        Invoke-WebRequest -Uri $msixUrl -OutFile $msixPath -UseBasicParsing
        Invoke-WebRequest -Uri $licenseUrl -OutFile $licensePath -UseBasicParsing

        # Install winget (current user + provision for all users)
        Write-Output "  Installing Winget..."
        Add-AppxPackage -Path $msixPath -ErrorAction Stop
        Add-AppxProvisionedPackage -Online -PackagePath $msixPath -LicensePath $licensePath -ErrorAction Stop | Out-Null

        # Wait for winget to become available and refresh PATH
        Start-Sleep -Seconds 3
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        Write-Output "  Winget installed successfully."
    }
    catch {
        Write-Error "Failed to install Winget: $_"
        exit 1
    }
    finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Verify winget is now available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "Winget not available. A reboot may be required."
    exit 1
}

Write-Output "Installing apps for '$systemPurpose'..."

foreach ($app in $apps) {
    $packageId = $appDefinitions[$app]

    if (-not $packageId) {
        Write-Warning "Skipping '$app': not defined"
        continue
    }

    Write-Output "Installing $app ($packageId)..."
    $wingetArgs = "install --id=$packageId -e --silent --source winget --accept-package-agreements --accept-source-agreements"
    $process = Start-Process -FilePath "winget" -ArgumentList $wingetArgs -NoNewWindow -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        Write-Warning "Failed to install $app (exit code: $($process.ExitCode))"
    }
}

Write-Output "Installation complete."

# Create WhatsApp Web shortcut (InPrivate mode) for shared computers
if ($systemOwnership -eq "shared") {
    Write-Output "Creating WhatsApp Web shortcut (InPrivate mode)..."

    $shortcutPath = "C:\Users\Public\Desktop\WhatsApp.lnk"
    $iconPath = "C:\Windows\deploy\whatsapp.ico"
    $edgePath = if (Test-Path "C:\Program Files\Microsoft\Edge\Application\msedge.exe") {
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    }
    else {
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    }
    $arguments = "--app=https://web.whatsapp.com --inprivate --window-size=800,600"

    # Download WhatsApp icon
    $iconUrl = "https://web.whatsapp.com/favicon.ico"
    try {
        Invoke-WebRequest -Uri $iconUrl -OutFile $iconPath -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not download WhatsApp icon"
    }

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $edgePath
    $shortcut.Arguments = $arguments
    $shortcut.Description = "WhatsApp Web (InPrivate - geen data wordt opgeslagen)"
    if (Test-Path $iconPath) {
        $shortcut.IconLocation = "$iconPath,0"
    }
    $shortcut.Save()

    Write-Output "WhatsApp Web shortcut created on Public Desktop."
}

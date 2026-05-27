# Define script parameters
param (
    [string]$systemPurpose,
    [string]$systemOwnership
)

. (Join-Path $PSScriptRoot "_common.ps1")

<#
This script installs applications based on the specified purpose.
'systemPurpose' should be "radio", "tv", "editorial", or "plain".
#>

function New-Shortcut {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string]$Path,
        [string]$TargetPath,
        [string]$Arguments,
        [string]$WorkingDirectory,
        [string]$Description,
        [string]$IconPath
    )

    if ($PSCmdlet.ShouldProcess($Path, "Create shortcut")) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($Path)
        $shortcut.TargetPath = $TargetPath
        if ($Arguments) { $shortcut.Arguments = $Arguments }
        if ($WorkingDirectory) { $shortcut.WorkingDirectory = $WorkingDirectory }
        if ($Description) { $shortcut.Description = $Description }
        if ($IconPath -and (Test-Path $IconPath)) { $shortcut.IconLocation = "$IconPath,0" }
        $shortcut.Save()
    }
}

# Winget package IDs (apps installed via winget)
$appDefinitions = @{
    "audacity"      = "Audacity.Audacity"
    "creativecloud" = "Adobe.CreativeCloud"
    "libreoffice"   = "TheDocumentFoundation.LibreOffice"
    "msteams"       = "Microsoft.Teams"
    "pinta"         = "Pinta.Pinta"
    "thunderbird"   = "Mozilla.Thunderbird"
    "vlc"           = "VideoLAN.VLC"
}

# Apps requiring special installation (not via winget)
$specialApps = @("spotify", "office")

# Applications by purpose
$appsByPurpose = @{
    "radio"     = @("audacity", "libreoffice", "spotify", "thunderbird", "vlc")
    "tv"        = @("creativecloud", "libreoffice", "vlc")
    "editorial" = @("audacity", "msteams", "office", "pinta", "vlc")
    "plain"     = @()
}

# Validate parameters
if (-not $systemPurpose) {
    throw "'systemPurpose' parameter must be provided."
}

$systemPurpose = $systemPurpose.ToLower()
if (-not $appsByPurpose.ContainsKey($systemPurpose)) {
    throw "Invalid 'systemPurpose': $systemPurpose. Valid values: radio, tv, editorial, plain"
}

# Get apps for this purpose
$apps = $appsByPurpose[$systemPurpose]

if ($apps.Count -eq 0) {
    Write-Output "No apps to install for '$systemPurpose'."
    return
}

# Install winget if not available (required for LTSC which has no Microsoft Store)
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Output "Winget not found. Installing for LTSC..."

    $tempDir = Join-Path $env:TEMP "winget-install"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $ProgressPreference = 'SilentlyContinue'

    try {
        # Get latest winget release info from GitHub
        Write-Output "  Fetching latest Winget release..."
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing
        $msixUrl = ($release.assets | Where-Object { $_.name -match "\.msixbundle$" }).browser_download_url
        $licenseUrl = ($release.assets | Where-Object { $_.name -match "License.*\.xml$" }).browser_download_url
        $depsUrl = ($release.assets | Where-Object { $_.name -eq "DesktopAppInstaller_Dependencies.zip" }).browser_download_url

        # Download dependencies zip (contains VCLibs + WindowsAppRuntime)
        Write-Output "  Downloading dependencies..."
        $depsZip = Join-Path $tempDir "deps.zip"
        $depsDir = Join-Path $tempDir "deps"
        Invoke-Download -Uri $depsUrl -OutFile $depsZip
        Expand-Archive -Path $depsZip -DestinationPath $depsDir -Force

        # Detect architecture and install matching dependencies
        $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "x64" }
        Write-Output "  Installing dependencies for $arch..."
        Get-ChildItem -Path (Join-Path $depsDir $arch) -Filter "*.appx" | ForEach-Object {
            Add-AppxPackage -Path $_.FullName -ErrorAction SilentlyContinue
        }

        # Download winget msixbundle and license
        Write-Output "  Downloading Winget..."
        $msixPath = Join-Path $tempDir "winget.msixbundle"
        $licensePath = Join-Path $tempDir "license.xml"
        Invoke-Download -Uri $msixUrl -OutFile $msixPath
        Invoke-Download -Uri $licenseUrl -OutFile $licensePath

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
        throw "Failed to install Winget: $($_.Exception.Message)"
    }
    finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Verify winget is now available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "Winget not available. A reboot may be required."
}

Write-Output "Installing apps for '$systemPurpose'..."

$failedApps = [System.Collections.Generic.List[string]]::new()

# `winget install` exit codes that mean "no-op, package already in the requested state".
# Treated as success so `-OnlyRun apps` is idempotent on already-deployed workstations.
# Codes verified against microsoft/winget-cli AppInstallerErrors.h:
#   0x8A15002B UPDATE_NOT_APPLICABLE       (-1978335189) - winget itself
#   0x8A150061 PACKAGE_ALREADY_INSTALLED   (-1978335135) - winget itself
#   0x8A15010D INSTALL_ALREADY_INSTALLED   (-1978334963) - underlying MSI/EXE installer
$wingetSuccessExitCodes = @(0, -1978335189, -1978335135, -1978334963)

# Install apps via winget
foreach ($app in $apps) {
    # Skip special apps (handled separately)
    if ($specialApps -contains $app) {
        continue
    }

    $packageId = $appDefinitions[$app]

    if (-not $packageId) {
        throw "App '$app' is selected for purpose '$systemPurpose' but is not defined in the app catalog. This is a baseline bug; add it to either the winget definitions or the special-installer list."
    }

    Write-Output "Installing $app ($packageId)..."
    try {
        Invoke-NativeCommand -FilePath "winget" `
            -Arguments @("install", "--id=$packageId", "-e", "--silent", "--source", "winget", "--accept-package-agreements", "--accept-source-agreements") `
            -SuccessExitCodes $wingetSuccessExitCodes `
            -FailureMessage "Failed to install $app" | Out-Null
    }
    catch {
        Write-Warning $_.Exception.Message
        $failedApps.Add($app)
    }
}

# Install Spotify (requires special handling - winget fails in admin context)
if ($apps -contains "spotify") {
    Write-Output "Installing Spotify (direct download)..."

    $spotifyInstaller = Join-Path $env:TEMP "SpotifyFullSetup.exe"
    $spotifyPath = "C:\Program Files\Spotify"

    try {
        Write-Output "  Downloading Spotify installer..."
        Invoke-Download -Uri "https://download.spotify.com/SpotifyFullSetup.exe" -OutFile $spotifyInstaller

        Write-Output "  Extracting to $spotifyPath..."
        $process = Start-Process -FilePath $spotifyInstaller -ArgumentList "/extract `"$spotifyPath`"" -NoNewWindow -Wait -PassThru

        if ($process.ExitCode -ne 0) {
            throw "Spotify installer returned exit code $($process.ExitCode)."
        }

        Write-Output "  Spotify installed successfully"

        New-Shortcut -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Spotify.lnk" `
            -TargetPath "$spotifyPath\Spotify.exe" -WorkingDirectory $spotifyPath -Description "Spotify"
        Write-Output "  Start Menu shortcut created"

        New-Shortcut -Path "C:\Users\Public\Desktop\Spotify.lnk" `
            -TargetPath "$spotifyPath\Spotify.exe" -WorkingDirectory $spotifyPath -Description "Spotify"
        Write-Output "  Desktop shortcut created"
    }
    catch {
        Write-Warning "Failed to install Spotify: $($_.Exception.Message)"
        $failedApps.Add("spotify")
    }
    finally {
        Remove-Item -Path $spotifyInstaller -Force -ErrorAction SilentlyContinue
    }
}

# Install Microsoft Office (using Office Deployment Tool)
if ($apps -contains "office") {
    Write-Output "Installing Microsoft Office..."

    $officeConfigPath = Join-DeployPath "config\office.xml"
    $odtUrl = "https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_19628-20046.exe"
    $tempDir = Join-Path $env:TEMP "odt-install"

    try {
        if (-not (Test-Path $officeConfigPath)) {
            throw "Office config file not found at $officeConfigPath (deployment package is incomplete)."
        }

        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        Write-Output "  Downloading Office Deployment Tool..."
        $odtExe = Join-Path $tempDir "odt.exe"
        Invoke-Download -Uri $odtUrl -OutFile $odtExe

        Write-Output "  Extracting ODT..."
        Invoke-NativeCommand -FilePath $odtExe `
            -Arguments @("/extract:$tempDir", "/quiet") `
            -FailureMessage "Failed to extract Office Deployment Tool" | Out-Null

        $setupExe = Join-Path $tempDir "setup.exe"
        Write-Output "  Running Office setup..."
        Invoke-NativeCommand -FilePath $setupExe `
            -Arguments @("/configure", $officeConfigPath) `
            -FailureMessage "Failed to install Microsoft Office" | Out-Null
        Write-Output "  Microsoft Office installed successfully"
    }
    catch {
        Write-Warning "Failed to install Microsoft Office: $($_.Exception.Message)"
        $failedApps.Add("office")
    }
    finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($failedApps.Count -gt 0) {
    throw "App installation failed for: $($failedApps -join ', '). The workstation is not deployment-ready for '$systemPurpose'; re-run with -OnlyRun apps after investigating."
}

Write-Output "Installation complete."

# Create WhatsApp Web shortcut (InPrivate mode) for shared computers
if ($systemOwnership -eq "shared") {
    Write-Output "Creating WhatsApp Web shortcut (InPrivate mode)..."

    $shortcutPath = "C:\Users\Public\Desktop\WhatsApp.lnk"
    $iconPath = Join-DeployPath "whatsapp.ico"
    $edgePath = if (Test-Path "C:\Program Files\Microsoft\Edge\Application\msedge.exe") {
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    }
    else {
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    }
    $arguments = "--app=https://web.whatsapp.com --inprivate --mute-audio --window-size=800,600"

    # Download WhatsApp icon
    $iconUrl = "https://web.whatsapp.com/favicon.ico"
    try {
        Invoke-Download -Uri $iconUrl -OutFile $iconPath
    }
    catch {
        Write-Warning "Could not download WhatsApp icon"
    }

    New-Shortcut -Path $shortcutPath -TargetPath $edgePath -Arguments $arguments `
        -Description "WhatsApp Web (InPrivate - geen data wordt opgeslagen)" -IconPath $iconPath

    Write-Output "WhatsApp Web shortcut created on Public Desktop."
}

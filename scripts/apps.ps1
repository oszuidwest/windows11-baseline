# Define script parameters
param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName,
    [string]$dwAgentCode,
    [string]$dedicatedUserName,
    [string]$personalUserName
)

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

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($Path)
    $shortcut.TargetPath = $TargetPath
    if ($Arguments) { $shortcut.Arguments = $Arguments }
    if ($WorkingDirectory) { $shortcut.WorkingDirectory = $WorkingDirectory }
    if ($Description) { $shortcut.Description = $Description }
    if ($IconPath -and (Test-Path $IconPath)) { $shortcut.IconLocation = "$IconPath,0" }
    $shortcut.Save()
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
        Invoke-WebRequest -Uri $depsUrl -OutFile $depsZip -UseBasicParsing
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

# Install apps via winget
foreach ($app in $apps) {
    # Skip special apps (handled separately)
    if ($specialApps -contains $app) {
        continue
    }

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

# Install Spotify (requires special handling - winget fails in admin context)
if ($apps -contains "spotify") {
    Write-Output "Installing Spotify (direct download)..."

    $spotifyInstaller = Join-Path $env:TEMP "SpotifyFullSetup.exe"
    $spotifyPath = "C:\Program Files\Spotify"

    try {
        # Download Spotify installer
        Write-Output "  Downloading Spotify installer..."
        Invoke-WebRequest -Uri "https://download.spotify.com/SpotifyFullSetup.exe" -OutFile $spotifyInstaller -UseBasicParsing

        # Extract to Program Files (machine-wide installation)
        Write-Output "  Extracting to $spotifyPath..."
        $process = Start-Process -FilePath $spotifyInstaller -ArgumentList "/extract `"$spotifyPath`"" -NoNewWindow -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Write-Output "  Spotify installed successfully"

            # Create shortcuts
            New-Shortcut -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Spotify.lnk" `
                -TargetPath "$spotifyPath\Spotify.exe" -WorkingDirectory $spotifyPath -Description "Spotify"
            Write-Output "  Start Menu shortcut created"

            New-Shortcut -Path "C:\Users\Public\Desktop\Spotify.lnk" `
                -TargetPath "$spotifyPath\Spotify.exe" -WorkingDirectory $spotifyPath -Description "Spotify"
            Write-Output "  Desktop shortcut created"
        }
        else {
            Write-Warning "Spotify installation failed (exit code: $($process.ExitCode))"
        }
    }
    catch {
        Write-Warning "Failed to install Spotify: $_"
    }
    finally {
        Remove-Item -Path $spotifyInstaller -Force -ErrorAction SilentlyContinue
    }
}

# Install Microsoft Office (using Office Deployment Tool)
if ($apps -contains "office") {
    Write-Output "Installing Microsoft Office..."

    $officeConfigPath = "C:\Windows\deploy\config\office.xml"
    $odtUrl = "https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_19628-20046.exe"
    $tempDir = Join-Path $env:TEMP "odt-install"

    if (-not (Test-Path $officeConfigPath)) {
        Write-Warning "Office config file not found at $officeConfigPath"
    }
    else {
        try {
            # Create temp directory
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

            # Download Office Deployment Tool
            Write-Output "  Downloading Office Deployment Tool..."
            $odtExe = Join-Path $tempDir "odt.exe"
            Invoke-WebRequest -Uri $odtUrl -OutFile $odtExe -UseBasicParsing

            # Extract ODT (contains setup.exe)
            Write-Output "  Extracting ODT..."
            Start-Process -FilePath $odtExe -ArgumentList "/extract:$tempDir /quiet" -NoNewWindow -Wait

            # Run setup.exe with config
            $setupExe = Join-Path $tempDir "setup.exe"
            Write-Output "  Running Office setup..."
            $process = Start-Process -FilePath $setupExe -ArgumentList "/configure `"$officeConfigPath`"" -NoNewWindow -Wait -PassThru

            if ($process.ExitCode -eq 0) {
                Write-Output "  Microsoft Office installed successfully"
            }
            else {
                Write-Warning "Failed to install Microsoft Office (exit code: $($process.ExitCode))"
            }
        }
        catch {
            Write-Warning "Failed to install Microsoft Office: $_"
        }
        finally {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
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
    $arguments = "--app=https://web.whatsapp.com --inprivate --mute-audio --window-size=800,600"

    # Download WhatsApp icon
    $iconUrl = "https://web.whatsapp.com/favicon.ico"
    try {
        Invoke-WebRequest -Uri $iconUrl -OutFile $iconPath -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not download WhatsApp icon"
    }

    New-Shortcut -Path $shortcutPath -TargetPath $edgePath -Arguments $arguments `
        -Description "WhatsApp Web (InPrivate - geen data wordt opgeslagen)" -IconPath $iconPath

    Write-Output "WhatsApp Web shortcut created on Public Desktop."
}

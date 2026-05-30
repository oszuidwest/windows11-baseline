param (
    [string]$systemPurpose,
    [string]$systemOwnership
)

<#
.SYNOPSIS
    Installs apps selected by purpose and ownership.

.PARAMETER systemPurpose
    radio, tv, editorial, or plain.

.PARAMETER systemOwnership
    shared, personal, or dedicated.
#>

. (Join-Path $PSScriptRoot "_common.ps1")

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

$script:AppxPackageDowngradeHResult = -2147009274 # 0x80073D06: higher version already installed.

function Test-AppxPackageDowngradeError {
    param (
        [Parameter(Mandatory)]
        $ErrorRecord
    )

    $exception = $ErrorRecord.Exception
    while ($exception) {
        if ($exception.HResult -eq $script:AppxPackageDowngradeHResult) {
            return $true
        }
        $exception = $exception.InnerException
    }

    $errorText = $ErrorRecord | Out-String
    return (
        $errorText -match "0x80073D06" -or
        $errorText -match "higher version.*already installed" -or
        $errorText -match "hogere versie"
    )
}

function Install-WingetDependencyPackage {
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        Add-AppxPackage -Path $Path -ForceApplicationShutdown -ErrorAction Stop
        Write-Output "    Installed $([System.IO.Path]::GetFileName($Path))"
    }
    catch {
        if (Test-AppxPackageDowngradeError -ErrorRecord $_) {
            Write-Output "    Skipping $([System.IO.Path]::GetFileName($Path)) (newer version already installed)."
            return
        }
        throw
    }
}

$appDefinitions = @{
    "audacity"      = "Audacity.Audacity"
    "chrome"        = "Google.Chrome"
    "creativecloud" = "Adobe.CreativeCloud"
    "libreoffice"   = "TheDocumentFoundation.LibreOffice"
    "msteams"       = "Microsoft.Teams"
    "pinta"         = "Pinta.Pinta"
    "thunderbird"   = "Mozilla.Thunderbird"
    "vlc"           = "VideoLAN.VLC"
}

$specialApps = @("spotify", "office")

$appsByPurpose = @{
    "radio"     = @("audacity", "libreoffice", "spotify", "thunderbird", "vlc")
    "tv"        = @("creativecloud", "libreoffice", "vlc")
    "editorial" = @("audacity", "msteams", "office", "pinta", "vlc")
    "plain"     = @()
}

# Keep empty ownership entries explicit.
$appsByOwnership = @{
    "personal"  = @("chrome")
    "shared"    = @()
    "dedicated" = @()
}

$validPurposes = @($appsByPurpose.Keys | Sort-Object)
$validOwnership = @($appsByOwnership.Keys | Sort-Object)

if (-not $systemPurpose) {
    throw "'systemPurpose' parameter must be provided."
}

$systemPurpose = $systemPurpose.ToLower()
if (-not $appsByPurpose.ContainsKey($systemPurpose)) {
    throw "Invalid 'systemPurpose': $systemPurpose. Valid values: $($validPurposes -join ', ')"
}

if (-not $systemOwnership) {
    throw "'systemOwnership' parameter must be provided."
}

$systemOwnership = $systemOwnership.ToLower()
if (-not $appsByOwnership.ContainsKey($systemOwnership)) {
    throw "Invalid 'systemOwnership': $systemOwnership. Valid values: $($validOwnership -join ', ')"
}

# Deduplicate purpose and ownership selections.
$apps = @($appsByPurpose[$systemPurpose])
$apps += $appsByOwnership[$systemOwnership]
$apps = @($apps | Select-Object -Unique)

if ($apps.Count -eq 0) {
    Write-Output "No apps to install for purpose '$systemPurpose' and ownership '$systemOwnership'."
    return
}

# LTSC has no Microsoft Store, so bootstrap winget when missing.
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Output "Winget not found. Installing for LTSC..."

    $tempDir = Join-Path $env:TEMP "winget-install"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $ProgressPreference = 'SilentlyContinue'

    try {
        Write-Output "  Fetching latest Winget release..."
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing
        $msixUrl = ($release.assets | Where-Object { $_.name -match "\.msixbundle$" }).browser_download_url
        $licenseUrl = ($release.assets | Where-Object { $_.name -match "License.*\.xml$" }).browser_download_url
        $depsUrl = ($release.assets | Where-Object { $_.name -eq "DesktopAppInstaller_Dependencies.zip" }).browser_download_url

        Write-Output "  Downloading dependencies..."
        $depsZip = Join-Path $tempDir "deps.zip"
        $depsDir = Join-Path $tempDir "deps"
        Invoke-Download -Uri $depsUrl -OutFile $depsZip
        Expand-Archive -Path $depsZip -DestinationPath $depsDir -Force

        $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "x64" }
        Write-Output "  Installing dependencies for $arch..."
        Get-ChildItem -Path (Join-Path $depsDir $arch) -Filter "*.appx" | Sort-Object Name | ForEach-Object {
            Install-WingetDependencyPackage -Path $_.FullName
        }

        Write-Output "  Downloading Winget..."
        $msixPath = Join-Path $tempDir "winget.msixbundle"
        $licensePath = Join-Path $tempDir "license.xml"
        Invoke-Download -Uri $msixUrl -OutFile $msixPath
        Invoke-Download -Uri $licenseUrl -OutFile $licensePath

        Write-Output "  Installing Winget..."
        Add-AppxPackage -Path $msixPath -ForceApplicationShutdown -ErrorAction Stop
        Add-AppxProvisionedPackage -Online -PackagePath $msixPath -LicensePath $licensePath -ErrorAction Stop | Out-Null

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

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "Winget not available. A reboot may be required."
}

Write-Output "Installing apps for purpose '$systemPurpose' and ownership '$systemOwnership'..."

$failedApps = [System.Collections.Generic.List[string]]::new()

# Treat no-op winget results as idempotent success.
# Verified against microsoft/winget-cli AppInstallerErrors.h:
#   0x8A15002B UPDATE_NOT_APPLICABLE (-1978335189)
#   0x8A150061 PACKAGE_ALREADY_INSTALLED (-1978335135)
#   0x8A15010D INSTALL_ALREADY_INSTALLED (-1978334963)
$wingetSuccessExitCodes = @(0, -1978335189, -1978335135, -1978334963)

foreach ($app in $apps) {
    if ($specialApps -contains $app) {
        continue
    }

    $packageId = $appDefinitions[$app]

    if (-not $packageId) {
        throw "App '$app' is selected for purpose '$systemPurpose' and ownership '$systemOwnership' but is not defined in the app catalog. This is a baseline bug; add it to either the winget definitions or the special-installer list."
    }

    Write-Output "Installing $app ($packageId)..."
    try {
        Invoke-NativeCommand -FilePath "winget" `
            -Arguments @("install", "--id=$packageId", "-e", "--silent", "--source", "winget", "--accept-package-agreements", "--accept-source-agreements") `
            -SuccessExitCodes $wingetSuccessExitCodes `
            -FailureMessage "Failed to install $app" | Out-Null
    }
    catch {
        $failedApps.Add("$app ($($_.Exception.Message))")
    }
}

# Winget fails for Spotify in elevated installer context.
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
        $failedApps.Add("spotify ($($_.Exception.Message))")
    }
    finally {
        Remove-Item -Path $spotifyInstaller -Force -ErrorAction SilentlyContinue
    }
}

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
        $failedApps.Add("office ($($_.Exception.Message))")
    }
    finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($failedApps.Count -gt 0) {
    throw "App installation failed for: $($failedApps -join '; '). The workstation is not deployment-ready for '$systemPurpose'; re-run with -OnlyRun apps after investigating."
}

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

Write-Output "Installation complete."

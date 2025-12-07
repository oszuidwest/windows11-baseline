param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName
)

<#
.SYNOPSIS
    Installs and configures BGInfo for dedicated systems.

.DESCRIPTION
    Downloads BGInfo from Sysinternals and configures it to display system
    information on the desktop background. Only runs on dedicated systems.

    Displayed information includes:
    - Computer name
    - IP addresses
    - Network configuration
    - System specs

.NOTES
    BGInfo renders information onto the wallpaper at each login.
    Only applies to "dedicated" ownership type.
#>

# Only run for dedicated systems
if ($systemOwnership -ne "dedicated") {
    Write-Output "Skipping BGInfo setup (not a dedicated system)."
    exit 0
}

Write-Output "Setting up BGInfo for dedicated system..."

$deployPath = "C:\Windows\deploy"
$bgInfoExe = Join-Path $deployPath "bin\BGInfo64.exe"
$bgInfoConfig = Join-Path $deployPath "config\bginfo.bgi"
$startupFolder = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
$shortcutPath = Join-Path $startupFolder "BGInfo.lnk"

# Download BGInfo if not present
if (-not (Test-Path $bgInfoExe)) {
    Write-Output "Downloading BGInfo64.exe from Sysinternals..."
    $bgInfoUrl = "https://live.sysinternals.com/bginfo64.exe"
    try {
        Invoke-WebRequest -Uri $bgInfoUrl -OutFile $bgInfoExe -UseBasicParsing
        Write-Output "  BGInfo downloaded successfully."
    }
    catch {
        Write-Error "Failed to download BGInfo: $_"
        exit 1
    }
}

# Check if config exists
if (-not (Test-Path $bgInfoConfig)) {
    Write-Warning "BGInfo config not found at $bgInfoConfig"
    Write-Warning "BGInfo will run with default settings. Create a custom .bgi file for specific layout."
}

# Run BGInfo now to set initial wallpaper
Write-Output "Applying BGInfo to desktop..."
if (Test-Path $bgInfoConfig) {
    & $bgInfoExe $bgInfoConfig /silent /timer:0 /nolicprompt
}
else {
    # Run without config - will use defaults
    & $bgInfoExe /silent /timer:0 /nolicprompt /all
}

# Create startup shortcut for all users
Write-Output "Creating BGInfo startup shortcut..."
try {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $bgInfoExe
    if (Test-Path $bgInfoConfig) {
        $shortcut.Arguments = "`"$bgInfoConfig`" /silent /timer:0 /nolicprompt"
    }
    else {
        $shortcut.Arguments = "/silent /timer:0 /nolicprompt /all"
    }
    $shortcut.Description = "BGInfo - Display system information on desktop"
    $shortcut.Save()
    Write-Output "  Startup shortcut created."
}
catch {
    Write-Warning "Failed to create startup shortcut: $_"
}

Write-Output "BGInfo setup complete."

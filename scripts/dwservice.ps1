param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName,
    [string]$dwAgentCode,
    [string]$dedicatedUserName
)

<#
.SYNOPSIS
    Installs DWService remote access agent.

.DESCRIPTION
    Downloads and installs DWService agent for remote support and management.
    Configures as unattended agent using the provided agent code from dwservice.net.

.PARAMETER dwAgentCode
    The agent code from dwservice.net for unattended access configuration.

.NOTES
    DWService is installed on all systems (shared, personal, dedicated).
    If no agent code is provided, installation is skipped.
#>

# Skip if no agent code provided
if (-not $dwAgentCode -or $dwAgentCode -eq "") {
    Write-Output "Skipping DWService installation (no agent code provided)."
    exit 0
}

Write-Output "Installing DWService..."

$deployPath = "C:\Windows\deploy"
$installerPath = Join-Path $deployPath "dwagent.exe"
$dwServiceUrl = "https://www.dwservice.net/download/dwagent.exe"

# Download DWService installer
Write-Output "Downloading DWService agent..."
try {
    Invoke-WebRequest -Uri $dwServiceUrl -OutFile $installerPath -UseBasicParsing
    Write-Output "  Download complete."
}
catch {
    Write-Error "Failed to download DWService: $_"
    exit 1
}

# Install DWService silently with agent code
Write-Output "Installing DWService with agent code..."
try {
    $process = Start-Process -FilePath $installerPath -ArgumentList "-silent", "key=$dwAgentCode" -PassThru
    Write-Output "  Installer started (PID: $($process.Id))"

    # Poll every 60 seconds, max 5 minutes
    $maxMinutes = 5
    for ($i = 1; $i -le $maxMinutes; $i++) {
        $exited = $process.WaitForExit(60000)

        if ($exited) {
            Write-Output "  Installer exited with code: $($process.ExitCode)"
            break
        }
        else {
            Write-Output "  Still running after $i minute(s)..."
        }
    }

    if (-not $process.HasExited) {
        Write-Warning "Installer still running after $maxMinutes minutes, killing process..."
        $process.Kill()
    }
}
catch {
    Write-Error "Failed to install DWService: $_"
    exit 1
}

# Clean up installer
Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue

Write-Output "DWService installation complete."

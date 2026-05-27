param (
    [string]$dwAgentCode
)

. (Join-Path $PSScriptRoot "_common.ps1")

<#
.SYNOPSIS
    Installs DWService remote access agent.

.DESCRIPTION
    Downloads and installs DWService agent for remote support and management.
    Configures as a persistent remote-access agent using the provided agent code from dwservice.net.

.PARAMETER dwAgentCode
    The agent code from dwservice.net for remote access configuration.

.NOTES
    DWService is installed on all systems (shared, personal, dedicated).
    If no agent code is provided, installation is skipped.
#>

# Skip if no agent code provided
if (-not $dwAgentCode) {
    Write-Output "Skipping DWService installation (no agent code provided)."
    return
}

Write-Output "Installing DWService..."

$installerPath = Join-DeployPath "dwagent.exe"
$dwServiceUrl = "https://www.dwservice.net/download/dwagent.exe"

# Download DWService installer
Write-Output "Downloading DWService agent..."
try {
    Invoke-Download -Uri $dwServiceUrl -OutFile $installerPath
    Write-Output "  Download complete."
}
catch {
    throw "Failed to download DWService: $($_.Exception.Message)"
}

# Run the DWService installer with the configured agent code.
Write-Output "Installing DWService with agent code..."
$maxMinutes = 5
try {
    $process = Start-Process -FilePath $installerPath -ArgumentList "-silent", "key=$dwAgentCode" -PassThru
    Write-Output "  Installer started (PID: $($process.Id))"

    for ($i = 1; $i -le $maxMinutes; $i++) {
        if ($process.WaitForExit(60000)) {
            break
        }
        Write-Output "  Still running after $i minute(s)..."
    }

    if (-not $process.HasExited) {
        $killed = $true
        try {
            $process.Kill()
        }
        catch {
            $killed = $false
            Write-Warning "Could not kill DWService installer (PID $($process.Id)): $($_.Exception.Message)"
        }
        $killState = if ($killed) { "process was killed" } else { "kill attempt failed (PID $($process.Id) may still be running)" }
        throw "DWService installer did not exit within $maxMinutes minutes; $killState."
    }

    $exitCode = $process.ExitCode
    Write-Output "  Installer exited with code: $exitCode"

    if ($exitCode -ne 0) {
        throw "DWService installer returned non-zero exit code $exitCode."
    }
}
finally {
    Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
}

Write-Output "DWService installation complete."

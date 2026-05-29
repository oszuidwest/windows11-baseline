param (
    [string]$dwAgentCode
)

<#
.SYNOPSIS
    Installs DWService remote access agent.

.DESCRIPTION
    Downloads DWService and configures it with the provided dwservice.net agent code.

.PARAMETER dwAgentCode
    Agent code used to bind this machine.

.NOTES
    Installation is skipped when no code is provided.
#>

. (Join-Path $PSScriptRoot "_common.ps1")

if (-not $dwAgentCode) {
    Write-Output "Skipping DWService installation (no agent code provided)."
    return
}

Write-Output "Installing DWService..."

$installerPath = Join-DeployPath "dwagent.exe"
$dwServiceUrl = "https://www.dwservice.net/download/dwagent.exe"

Write-Output "Downloading DWService agent..."
try {
    Invoke-Download -Uri $dwServiceUrl -OutFile $installerPath
    Write-Output "  Download complete."
}
catch {
    throw "Failed to download DWService: $($_.Exception.Message)"
}

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

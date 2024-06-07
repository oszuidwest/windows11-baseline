# Application scripts for each purpose
$applicationScripts = @{
    "Radio"     = @("app-audacity.ps1", "app-libreoffice.ps1", "app-thunderbird.ps1", "app-vlc.ps1")
    "TV"        = @("app-creativecloud.ps1", "app-libreoffice.ps1", "app-vlc.ps1")
    "Editorial" = @("app-audacity.ps1", "app-libreoffice.ps1", "app-msteams.ps1", "app-pintra.ps1", "app-vlc.ps1")
    "Plain"     = @()
}

# Function to install an application based on the purpose
function Install-Application {
    param (
        [string]$purpose
    )
    
    # Base directory where scripts are located
    $baseDirectory = "C:\Windows\deploy\install"
    
    # Get the list of scripts for the selected purpose
    $scripts = $applicationScripts[$purpose]

    if ($scripts.Count -eq 0) {
        Write-Output "No applications to install for $purpose purpose."
        return
    }

    # Execute each script
    foreach ($script in $scripts) {
        $scriptPath = Join-Path -Path $baseDirectory -ChildPath $script
        if (Test-Path $scriptPath) {
            Write-Output "Executing $script..."
            & "$scriptPath"
        }
        else {
            Write-Warning "Script not found: $scriptPath"
        }
    }
}

# Main execution
Write-Output "Choose the purpose for this computer:"
Write-Output "1. Radio"
Write-Output "2. TV"
Write-Output "3. Editorial"
Write-Output "4. Plain"

$choice = Read-Host "Enter your choice (1-4)"

switch ($choice) {
    "1" { $purpose = "Radio" }
    "2" { $purpose = "TV" }
    "3" { $purpose = "Editorial" }
    "4" { $purpose = "Plain" }
    default {
        Write-Output "Invalid choice. Exiting."
        exit
    }
}

Write-Output "Setting up the computer for $purpose purpose..."
Install-Application -purpose $purpose
Write-Output "Setup complete."

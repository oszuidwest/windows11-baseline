# Application scripts for each purpose
$applicationScripts = @{
    "Radio"     = @("app-audacity.ps1", "app-libreoffice.ps1", "app-thunderbird.ps1", "app-vlc.ps1")
    "TV"        = @("app-creativecloud.ps1", "app-libreoffice.ps1", "app-vlc.ps1")
    "Editorial" = @("app-audacity.ps1", "app-libreoffice.ps1", "app-msteams.ps1", "app-pintra.ps1", "app-vlc.ps1")
    "Plain"     = @()
}

# Function to install applications based on the purpose
function Install-Applications {
    param (
        [string]$purpose
    )
    
    # Base directory where scripts are located
    $baseDirectory = "C:\windows\deploy\install"
    
    # Get the list of scripts for the selected purpose
    $scripts = $applicationScripts[$purpose]

    if ($scripts.Count -eq 0) {
        Write-Host "No applications to install for $purpose purpose."
        return
    }

    # Execute each script
    foreach ($script in $scripts) {
        $scriptPath = Join-Path -Path $baseDirectory -ChildPath $script
        if (Test-Path $scriptPath) {
            Write-Host "Executing $script..."
            & "$scriptPath"
        }
        else {
            Write-Host "Script not found: $scriptPath"
        }
    }
}

# Main execution
Write-Host "Choose the purpose for this computer:"
Write-Host "1. Radio"
Write-Host "2. TV"
Write-Host "3. Editorial"
Write-Host "4. Plain"

$choice = Read-Host "Enter your choice (1-4)"

switch ($choice) {
    "1" { $purpose = "Radio" }
    "2" { $purpose = "TV" }
    "3" { $purpose = "Editorial" }
    "4" { $purpose = "Plain" }
    default {
        Write-Host "Invalid choice. Exiting."
        exit
    }
}

Write-Host "Setting up the computer for $purpose purpose..."
Install-Applications -purpose $purpose
Write-Host "Setup complete."


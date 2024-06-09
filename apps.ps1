<#
This script installs a set of applications based on the specified purpose and ownership type. 
The 'purpose' parameter should be one of "radio", "tv", "editorial", or "plain".
The 'ownership' parameter should specify the type of ownership, such as "shared", "personal", or "dedicated". 
Both parameters are required for the script to run. 
If they are not provided, the script will print an error message and exit.
#>

# Application scripts for each purpose in lowercase
$applicationScripts = @{
    "radio"     = @("app-audacity.ps1", "app-libreoffice.ps1", "app-thunderbird.ps1", "app-vlc.ps1")
    "tv"        = @("app-creativecloud.ps1", "app-libreoffice.ps1", "app-vlc.ps1")
    "editorial" = @("app-audacity.ps1", "app-libreoffice.ps1", "app-msteams.ps1", "app-pintra.ps1", "app-vlc.ps1")
    "plain"     = @()
}

# Function to install applications based on the purpose
function Install-Application {
    param (
        [string]$purpose,
        [string]$ownership
    )
    
    # Ensure purpose is lowercase
    $purpose = $purpose.ToLower()

    # Base directory where scripts are located
    $baseDirectory = "C:\windows\deploy\install"
    
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
            Write-Output "Executing $script for $ownership ownership..."
            & "$scriptPath"
        }
        else {
            Write-Warning "Script not found: $scriptPath"
        }
    }
}

# Main execution
param (
    [string]$purpose,
    [string]$ownership
)

# Check if required parameters are provided
if (-not $PSCmdlet.MyInvocation.BoundParameters["purpose"] -or -not $PSCmdlet.MyInvocation.BoundParameters["ownership"]) {
    Write-Error "Error: Both 'purpose' and 'ownership' parameters must be provided."
    exit
}

# Convert purpose to lowercase
$purpose = $purpose.ToLower()

if (-not $applicationScripts.ContainsKey($purpose)) {
    Write-Error "Invalid purpose provided. Exiting."
    exit
}

Write-Output "Installing applications for $purpose purpose with $ownership ownership..."
Install-Application -purpose $purpose -ownership $ownership
Write-Output "Application installation complete."

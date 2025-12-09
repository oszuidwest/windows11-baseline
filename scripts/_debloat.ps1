# Define script parameters
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
This script removes bloatware from Windows 11.
Runs for all system purposes and ownership types.
#>

$appsToRemove = @(
    "Microsoft.WindowsCamera"
    "Microsoft.Copilot"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.Windows.Photos"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.BingNews"
    "Microsoft.WindowsStore"
    "Microsoft.Todos"
    "Microsoft.OutlookForWindows"
    "MicrosoftCorporationII.QuickAssist"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.YourPhone"
    "Clipchamp.Clipchamp"
    "MSTeams"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.StartExperiencesApp"
    "Microsoft.GetHelp"
    "Microsoft.BingSearch"
    "Microsoft.BingWeather"
    "Microsoft.Edge.GameAssist"
    "Microsoft.Windows.DevHome"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.ZuneMusic"
    "MicrosoftWindows.Client.WebExperience"
    "Microsoft.WidgetsPlatformRuntime"
    "MicrosoftWindows.CrossDevice"
)

Write-Output "Removing Windows bloatware..."

foreach ($app in $appsToRemove) {
    Write-Output "Removing: $app"

    # Remove for all users
    try {
        Get-AppxPackage -AllUsers -ErrorAction Stop |
            Where-Object { $_.Name -like "*$app*" } |
            ForEach-Object {
                Write-Output "  Removing package: $($_.Name)"
                try {
                    Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop
                }
                catch {
                    Write-Warning "  Failed to remove $($_.Name): $_"
                }
            }
    }
    catch {
        Write-Warning "  Could not query packages for $app"
    }

    # Remove provisioned package (prevents reinstallation for new users/updates)
    try {
        Get-AppxProvisionedPackage -Online -ErrorAction Stop |
            Where-Object { $_.DisplayName -like "*$app*" -or $_.PackageName -like "*$app*" } |
            ForEach-Object {
                Write-Output "  Removing provisioned package: $($_.DisplayName)"
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction Stop | Out-Null
                }
                catch {
                    Write-Warning "  Failed to remove provisioned $($_.DisplayName): $_"
                }
            }
    }
    catch {
        Write-Warning "  Could not query provisioned packages for $app"
    }
}

Write-Output "Bloatware removal complete."

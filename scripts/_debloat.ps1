# Define script parameters
param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName
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
    Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*$app*" } |
        ForEach-Object {
            Write-Output "  Removing package: $($_.Name)"
            Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        }

    # Remove provisioned package (prevents reinstallation for new users/updates)
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*$app*" -or $_.PackageName -like "*$app*" } |
        ForEach-Object {
            Write-Output "  Removing provisioned package: $($_.DisplayName)"
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue
        }
}

Write-Output "Bloatware removal complete."

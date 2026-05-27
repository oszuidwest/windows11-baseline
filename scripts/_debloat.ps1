param()

<#
This script removes bloatware from Windows 11.
Runs for all system purposes and ownership types.
#>

function Remove-BloatwareApp {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string]$AppName
    )

    # Remove installed packages for all users
    Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*$AppName*" } |
        ForEach-Object {
            Write-Output "  Removing: $($_.Name)"
            if ($PSCmdlet.ShouldProcess($_.PackageFullName, "Remove Appx package")) {
                Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
            }
        }

    # Remove provisioned packages (prevents reinstallation)
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*$AppName*" -or $_.PackageName -like "*$AppName*" } |
        ForEach-Object {
            Write-Output "  Removing provisioned: $($_.DisplayName)"
            if ($PSCmdlet.ShouldProcess($_.PackageName, "Remove provisioned Appx package")) {
                Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
            }
        }
}

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
    Remove-BloatwareApp -AppName $app
}

Write-Output "Bloatware removal complete."

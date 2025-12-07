param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName,
    [string]$dwAgentCode
)

<#
.SYNOPSIS
    Checks for and installs Windows updates.

.DESCRIPTION
    Uses the Windows Update Agent API to search for, download, and install
    all available updates. Runs at the end of the baseline deployment.

.NOTES
    A reboot may be required after updates are installed.
#>

Write-Output "Checking for Windows updates..."

# Create Windows Update Session
$updateSession = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateUpdateSearcher()

# Search for updates
Write-Output "Searching for available updates..."
try {
    $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
}
catch {
    Write-Error "Failed to search for updates: $_"
    exit 1
}

$updates = $searchResult.Updates

if ($updates.Count -eq 0) {
    Write-Output "No updates available."
    exit 0
}

Write-Output "Found $($updates.Count) update(s):"
foreach ($update in $updates) {
    Write-Output "  - $($update.Title)"
}

# Create update collection for download
$updatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
foreach ($update in $updates) {
    if (-not $update.IsDownloaded) {
        $updatesToDownload.Add($update) | Out-Null
    }
}

# Download updates
if ($updatesToDownload.Count -gt 0) {
    Write-Output ""
    Write-Output "Downloading $($updatesToDownload.Count) update(s)..."
    $downloader = $updateSession.CreateUpdateDownloader()
    $downloader.Updates = $updatesToDownload
    try {
        $downloader.Download() | Out-Null
        Write-Output "  Download complete."
    }
    catch {
        Write-Warning "Download failed: $_"
    }
}

# Create update collection for installation
$updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
foreach ($update in $updates) {
    if ($update.IsDownloaded) {
        $updatesToInstall.Add($update) | Out-Null
    }
}

# Install updates
if ($updatesToInstall.Count -gt 0) {
    Write-Output ""
    Write-Output "Installing $($updatesToInstall.Count) update(s)..."
    $installer = $updateSession.CreateUpdateInstaller()
    $installer.Updates = $updatesToInstall
    try {
        $installResult = $installer.Install()

        Write-Output "  Installation complete."
        Write-Output "  Result code: $($installResult.ResultCode)"

        if ($installResult.RebootRequired) {
            Write-Output ""
            Write-Warning "A reboot is required to complete the update installation."
        }
    }
    catch {
        Write-Error "Installation failed: $_"
        exit 1
    }
}

Write-Output ""
Write-Output "Windows Update complete."

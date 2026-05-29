param()

. (Join-Path $PSScriptRoot "_common.ps1")

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

$updateSession = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateUpdateSearcher()

Write-Output "Searching for available updates..."
try {
    $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
}
catch {
    throw "Failed to search for updates: $($_.Exception.Message)"
}

$updates = $searchResult.Updates

if ($updates.Count -eq 0) {
    Write-Output "No updates available."
    return
}

Write-Output "Found $($updates.Count) update(s):"
foreach ($update in $updates) {
    Write-Output "  - $($update.Title)"
}

$updatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
foreach ($update in $updates) {
    if (-not $update.IsDownloaded) {
        $updatesToDownload.Add($update) | Out-Null
    }
}

if ($updatesToDownload.Count -gt 0) {
    Write-Output ""
    Write-Output "Downloading $($updatesToDownload.Count) update(s)..."
    $downloader = $updateSession.CreateUpdateDownloader()
    $downloader.Updates = $updatesToDownload
    try {
        $downloadResult = $downloader.Download()
    }
    catch {
        throw "Windows Update download failed: $($_.Exception.Message)"
    }

    Assert-WuaOperationSucceeded -OperationResult $downloadResult -Updates $updatesToDownload -Phase 'Download'

    $downloadedCount = 0
    for ($idx = 0; $idx -lt $updatesToDownload.Count; $idx++) {
        if ($updatesToDownload.Item($idx).IsDownloaded) {
            $downloadedCount++
        }
    }
    $missingCount = $updatesToDownload.Count - $downloadedCount
    if ($missingCount -gt 0) {
        throw "Windows Update reported $missingCount of $($updatesToDownload.Count) update(s) failed to download; refusing to install a partial set."
    }
    Write-Output "  All $downloadedCount update(s) downloaded."
}

$updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
foreach ($update in $updates) {
    if ($update.IsDownloaded) {
        $updatesToInstall.Add($update) | Out-Null
    }
}

if ($updatesToInstall.Count -gt 0) {
    Write-Output ""
    Write-Output "Installing $($updatesToInstall.Count) update(s)..."
    $installer = $updateSession.CreateUpdateInstaller()
    $installer.Updates = $updatesToInstall
    try {
        $installResult = $installer.Install()
    }
    catch {
        throw "Windows Update install call failed: $($_.Exception.Message)"
    }

    Assert-WuaOperationSucceeded -OperationResult $installResult -Updates $updatesToInstall -Phase 'Install'

    if ($installResult.RebootRequired) {
        Write-Output ""
        Write-Warning "A reboot is required to complete the update installation."
    }
}

Write-Output ""
Write-Output "Windows Update complete."

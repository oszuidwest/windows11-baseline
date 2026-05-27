param()

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

# WUA OperationResultCode: 0=NotStarted, 1=InProgress, 2=Succeeded, 3=SucceededWithErrors, 4=Failed, 5=Aborted
$resultCodeNames = @{
    0 = 'NotStarted'
    1 = 'InProgress'
    2 = 'Succeeded'
    3 = 'SucceededWithErrors'
    4 = 'Failed'
    5 = 'Aborted'
}

# Create Windows Update Session
$updateSession = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateUpdateSearcher()

# Search for updates
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
        $downloadResult = $downloader.Download()
    }
    catch {
        throw "Windows Update download failed: $($_.Exception.Message)"
    }

    $downloadCode = [int]$downloadResult.ResultCode
    $downloadName = $resultCodeNames[$downloadCode]
    if (-not $downloadName) { $downloadName = "Unknown($downloadCode)" }
    Write-Output "  Download operation result: $downloadName ($downloadCode)"

    if ($downloadCode -ne 2) {
        $failedTitles = @()
        for ($idx = 0; $idx -lt $updatesToDownload.Count; $idx++) {
            $perResult = $downloadResult.GetUpdateResult($idx)
            $perCode = [int]$perResult.ResultCode
            if ($perCode -ne 2) {
                $hresult = "0x{0:X8}" -f ([int]$perResult.HResult)
                $title = $updatesToDownload.Item($idx).Title
                $perName = $resultCodeNames[$perCode]
                if (-not $perName) { $perName = "Unknown($perCode)" }
                $failedTitles += "  - $title ($perName, HRESULT $hresult)"
            }
        }

        $detail = if ($failedTitles.Count -gt 0) { "`n" + ($failedTitles -join "`n") } else { "" }
        throw "Windows Update download reported $downloadName ($downloadCode).$detail"
    }

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
    }
    catch {
        throw "Windows Update install call failed: $($_.Exception.Message)"
    }

    $resultCode = [int]$installResult.ResultCode
    $resultName = $resultCodeNames[$resultCode]
    if (-not $resultName) { $resultName = "Unknown($resultCode)" }
    Write-Output "  Install operation result: $resultName ($resultCode)"

    if ($resultCode -ne 2) {
        $failedTitles = @()
        for ($idx = 0; $idx -lt $updatesToInstall.Count; $idx++) {
            $perResult = $installResult.GetUpdateResult($idx)
            $perCode = [int]$perResult.ResultCode
            if ($perCode -ne 2) {
                $hresult = "0x{0:X8}" -f ([int]$perResult.HResult)
                $title = $updatesToInstall.Item($idx).Title
                $perName = $resultCodeNames[$perCode]
                if (-not $perName) { $perName = "Unknown($perCode)" }
                $failedTitles += "  - $title ($perName, HRESULT $hresult)"
            }
        }

        $detail = if ($failedTitles.Count -gt 0) { "`n" + ($failedTitles -join "`n") } else { "" }
        throw "Windows Update install reported $resultName ($resultCode).$detail"
    }

    if ($installResult.RebootRequired) {
        Write-Output ""
        Write-Warning "A reboot is required to complete the update installation."
    }
}

Write-Output ""
Write-Output "Windows Update complete."

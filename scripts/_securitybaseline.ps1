param()

<#
.SYNOPSIS
    Applies the Microsoft Windows 11 24H2 Security Baseline.

.DESCRIPTION
    Downloads, verifies, extracts, and applies the official Microsoft baseline
    before the ZuidWest-specific policy layer.
#>

. (Join-Path $PSScriptRoot "_common.ps1")

$ErrorActionPreference = "Stop"

$lgpoPath = Join-DeployPath "bin\LGPO.exe"
$baselineRoot = Join-DeployPath "microsoft-security-baseline"
$baselineZip = Join-Path $baselineRoot "Windows 11 v24H2 Security Baseline.zip"
$extractPath = Join-Path $baselineRoot "extracted"
$baselineUrl = "https://download.microsoft.com/download/8/5/c/85c25433-a1b0-4ffa-9429-7e023e7da8d8/Windows%2011%20v24H2%20Security%20Baseline.zip"
$expectedSha256 = "B75439A231C64EDACCAAD16A16268D199F56CE78273104E117D893F82CF174A5"

$baselineGpoNames = @(
    "MSFT Internet Explorer 11 - Computer",
    "MSFT Internet Explorer 11 - User",
    "MSFT Windows 11 24H2 - Computer",
    "MSFT Windows 11 24H2 - Credential Guard",
    "MSFT Windows 11 24H2 - Defender Antivirus",
    "MSFT Windows 11 24H2 - Domain Security",
    "MSFT Windows 11 24H2 - User"
)

Write-Output "=== Microsoft Windows 11 24H2 Security Baseline ==="
Write-Output ""

try {
    Assert-BundledBinary -BinaryPath $lgpoPath

    $currentBuild = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
    if ($currentBuild -ne "26100") {
        Write-Warning "This baseline is intended for Windows 11 24H2 (build 26100). Current build: $currentBuild"
    }

    if (Test-Path $baselineRoot) {
        Remove-Item -Path $baselineRoot -Recurse -Force
    }
    New-Item -Path $baselineRoot -ItemType Directory -Force | Out-Null

    Write-Output "Downloading Microsoft Security Compliance Toolkit baseline..."
    Invoke-Download -Uri $baselineUrl -OutFile $baselineZip

    Write-Output "Verifying baseline package hash..."
    $actualSha256 = (Get-FileHash -Path $baselineZip -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actualSha256 -ne $expectedSha256) {
        throw "Hash mismatch for Microsoft baseline package. Expected $expectedSha256, got $actualSha256"
    }

    Write-Output "Extracting baseline package..."
    Expand-Archive -Path $baselineZip -DestinationPath $extractPath -Force

    $baselineFolder = Get-ChildItem -Path $extractPath -Directory |
        Where-Object { $_.Name -eq "Windows 11 v24H2 Security Baseline" } |
        Select-Object -First 1

    if (-not $baselineFolder) {
        throw "Extracted baseline folder not found."
    }

    $baselinePath = $baselineFolder.FullName
    $gposPath = Join-Path $baselinePath "GPOs"
    $templatesPath = Join-Path $baselinePath "Templates"
    $configFilesPath = Join-Path (Join-Path $baselinePath "Scripts") "ConfigFiles"

    Write-Output "Mapping Microsoft baseline GPO names..."
    $gpoMap = @{}
    Get-ChildItem -Path $gposPath -Directory | ForEach-Object {
        $backupInfoPath = Join-Path $_.FullName "bkupInfo.xml"
        if (Test-Path $backupInfoPath) {
            $displayName = (Select-Xml -Path $backupInfoPath -XPath "//*[local-name()='GPODisplayName']").Node.InnerText
            $gpoMap[$displayName] = $_.FullName
        }
    }

    foreach ($gpoName in $baselineGpoNames) {
        if (-not $gpoMap.ContainsKey($gpoName)) {
            throw "Required Microsoft baseline GPO not found in package: $gpoName"
        }
    }

    Write-Output "Skipping Microsoft BitLocker GPO; ZuidWest applies removable-media-safe BitLocker settings separately."

    Write-Output "Copying Microsoft baseline administrative templates..."
    $policyDefinitionsPath = Join-Path $env:windir "PolicyDefinitions"
    $policyDefinitionsLanguagePath = Join-Path $policyDefinitionsPath "en-US"
    if (-not (Test-Path $policyDefinitionsLanguagePath)) {
        New-Item -Path $policyDefinitionsLanguagePath -ItemType Directory -Force | Out-Null
    }
    Copy-Item -Path (Join-Path $templatesPath "*.admx") -Destination $policyDefinitionsPath -Force
    Copy-Item -Path (Join-Path (Join-Path $templatesPath "en-US") "*.adml") -Destination $policyDefinitionsLanguagePath -Force

    Write-Output "Configuring required LGPO client-side extensions..."
    Invoke-NativeCommand -FilePath $lgpoPath `
        -Arguments @("/v", "/e", "mitigation", "/e", "audit", "/e", "zone", "/e", "DGVBS") `
        -FailureMessage "LGPO client-side extension configuration failed"

    Write-Output "Disabling Xbox Game Save scheduled task..."
    try {
        Invoke-NativeCommand -FilePath "schtasks.exe" `
            -Arguments @("/Change", "/TN", "\Microsoft\XblGameSave\XblGameSaveTask", "/DISABLE") `
            -FailureMessage "Could not disable Xbox Game Save scheduled task" | Out-Null
    }
    catch {
        Write-Warning $_.Exception.Message
    }

    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
    $isDomainJoined = [bool]$computerSystem.PartOfDomain
    if ($isDomainJoined) {
        Write-Output "System is domain-joined; applying Microsoft domain-joined baseline."
    }
    else {
        Write-Output "System is not domain-joined; applying Microsoft non-domain-joined baseline."
    }

    foreach ($gpoName in ($baselineGpoNames | Sort-Object)) {
        $gpoPath = $gpoMap[$gpoName]
        Write-Output "Applying: $gpoName"

        Invoke-NativeCommand -FilePath $lgpoPath `
            -Arguments @("/v", "/g", $gpoPath) `
            -FailureMessage "Failed to apply Microsoft baseline GPO '$gpoName'"
    }

    if (-not $isDomainJoined) {
        Write-Output "Backing out Microsoft local-account restrictions for non-domain-joined systems..."
        $deltaInf = Join-Path $configFilesPath "DeltaForNonDomainJoined.inf"
        $deltaTxt = Join-Path $configFilesPath "DeltaForNonDomainJoined.txt"

        Invoke-NativeCommand -FilePath $lgpoPath `
            -Arguments @("/v", "/s", $deltaInf, "/t", $deltaTxt) `
            -FailureMessage "Failed to apply non-domain-joined delta"
    }

    Write-Output ""
    Write-Output "Microsoft Windows 11 24H2 Security Baseline applied."
}
catch {
    throw "Failed to apply Microsoft security baseline: $($_.Exception.Message)"
}

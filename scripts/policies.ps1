param (
    [string]$systemPurpose,
    [string]$systemOwnership
)

<#
.SYNOPSIS
    Applies LGPO policies selected by purpose and ownership.

.DESCRIPTION
    Reads policies/config.json, filters matching policies, and applies them
    with LGPO.exe. User policies target non-admin accounts only.

.PARAMETER systemPurpose
    radio, tv, editorial, or plain.

.PARAMETER systemOwnership
    shared, personal, or dedicated.
#>

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_common.ps1")

$deployPath = Get-DeployPath
$lgpoPath = Join-DeployPath "bin\LGPO.exe"
$policiesPath = Join-DeployPath "policies"
$configPath = Join-Path $policiesPath "config.json"
$tempPath = Join-Path $deployPath "temp"

function Test-PolicyMatch {
    param (
        [array]$configuredScopes,
        [string]$currentValue
    )
    return ($configuredScopes -contains "all") -or ($configuredScopes -contains $currentValue.ToLower())
}

function Get-ApplicablePolicies {
    param (
        [object]$config,
        [string]$purpose,
        [string]$ownership
    )

    $applicable = @{
        Computer = @()
        User     = @()
    }

    foreach ($policyPath in $config.policies.PSObject.Properties.Name) {
        $policy = $config.policies.$policyPath

        $purposeMatch = Test-PolicyMatch -configuredScopes $policy.purposes -currentValue $purpose
        $ownershipMatch = Test-PolicyMatch -configuredScopes $policy.ownership -currentValue $ownership

        if ($purposeMatch -and $ownershipMatch) {
            $fullPath = Join-Path $policiesPath $policyPath

            if (Test-Path $fullPath) {
                $firstLine = Get-Content $fullPath -First 1
                if ($firstLine -eq "Computer") {
                    $applicable.Computer += $fullPath
                }
                elseif ($firstLine -eq "User") {
                    $applicable.User += $fullPath
                }
                else {
                    Write-Warning "Unknown policy type in $policyPath - skipping"
                }
                Write-Host "  [+] $policyPath"
            }
            else {
                Write-Warning "Policy file not found: $fullPath"
            }
        }
    }

    return $applicable
}

function Merge-PolicyFiles {
    param (
        [array]$policyFiles,
        [string]$outputPath
    )

    $content = $policyFiles | ForEach-Object {
        Get-Content $_ -Raw
        "`n"
    }
    $content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline
}

function Set-Policy {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [hashtable]$policies
    )

    if (-not (Test-Path $tempPath)) {
        New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
    }

    if ($policies.Computer.Count -gt 0 -and $PSCmdlet.ShouldProcess("Computer local policy", "Apply $($policies.Computer.Count) policies")) {
        Write-Output "`nApplying $($policies.Computer.Count) computer policies..."

        $computerTxt = Join-Path $tempPath "computer.txt"
        $computerPol = Join-Path $tempPath "computer.pol"

        Merge-PolicyFiles -policyFiles $policies.Computer -outputPath $computerTxt

        Invoke-NativeCommand -FilePath $lgpoPath `
            -Arguments @("/r", $computerTxt, "/w", $computerPol) `
            -FailureMessage "LGPO computer policy conversion failed"

        Invoke-NativeCommand -FilePath $lgpoPath `
            -Arguments @("/m", $computerPol) `
            -FailureMessage "LGPO computer policy apply failed"

        Write-Output "  Computer policies applied successfully"
    }

    if ($policies.User.Count -gt 0 -and $PSCmdlet.ShouldProcess("Non-admin user local policy", "Apply $($policies.User.Count) policies")) {
        Write-Output "`nApplying $($policies.User.Count) user policies (non-admin accounts)..."

        $userTxt = Join-Path $tempPath "user.txt"
        $userPol = Join-Path $tempPath "user.pol"

        Merge-PolicyFiles -policyFiles $policies.User -outputPath $userTxt

        Invoke-NativeCommand -FilePath $lgpoPath `
            -Arguments @("/r", $userTxt, "/w", $userPol) `
            -FailureMessage "LGPO user policy conversion failed"

        Invoke-NativeCommand -FilePath $lgpoPath `
            -Arguments @("/un", $userPol) `
            -FailureMessage "LGPO user policy apply failed"

        Write-Output "  User policies applied successfully"
    }

    Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "=== Windows 11 Policy Application ==="
Write-Output ""

if (-not $systemPurpose -or -not $systemOwnership) {
    throw "Both 'systemPurpose' and 'systemOwnership' parameters must be provided."
}

$systemPurpose = $systemPurpose.ToLower()
$systemOwnership = $systemOwnership.ToLower()

Assert-BundledBinary -BinaryPath $lgpoPath

if (-not (Test-Path $configPath)) {
    throw "Policy configuration not found at $configPath"
}

Write-Output "Purpose: $systemPurpose"
Write-Output "Ownership: $systemOwnership"
Write-Output ""

if ($systemOwnership -eq "shared" -or $systemOwnership -eq "personal") {
    $wallpaperUrl = "https://www.zuidwestupdate.nl/wp-content/uploads/2021/03/voorpagina-placeholder.png"
    $wallpaperDir = Join-ZuidWestPath "wallpaper"
    $wallpaperPath = Join-Path $wallpaperDir "wallpaper.png"

    Write-Output "Downloading wallpaper..."
    try {
        if (-not (Test-Path $wallpaperDir)) {
            New-Item -ItemType Directory -Path $wallpaperDir -Force | Out-Null
        }
        Invoke-Download -Uri $wallpaperUrl -OutFile $wallpaperPath
        Write-Output "  Wallpaper saved to $wallpaperPath"
    }
    catch {
        Write-Warning "Failed to download wallpaper: $_"
    }
    Write-Output ""
}

Write-Output "Finding applicable policies..."

$config = Get-Content $configPath -Raw | ConvertFrom-Json

$applicablePolicies = Get-ApplicablePolicies -config $config -purpose $systemPurpose -ownership $systemOwnership

$totalPolicies = $applicablePolicies.Computer.Count + $applicablePolicies.User.Count

if ($totalPolicies -eq 0) {
    Write-Output "`nNo applicable policies found for this configuration."
    return
}

Write-Output "`nFound $totalPolicies applicable policies"

Set-Policy -policies $applicablePolicies

Write-Output "`n=== Policy application complete ==="

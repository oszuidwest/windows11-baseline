param (
    [string]$systemPurpose,
    [string]$systemOwnership
)

. (Join-Path $PSScriptRoot "_common.ps1")

<#
.SYNOPSIS
    Applies Windows Group Policies based on system purpose and ownership.

.DESCRIPTION
    This script reads the policy configuration from policies/config.json,
    filters policies based on the system's purpose and ownership type,
    and applies them using LGPO.exe.

    - Computer policies (HKLM) are applied machine-wide
    - User policies (HKCU) are applied to non-administrator accounts only

.PARAMETER systemPurpose
    The purpose of the system: "radio", "tv", "editorial", or "plain"

.PARAMETER systemOwnership
    The ownership type: "shared", "personal", or "dedicated"
#>

# Paths
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
                # Determine if Computer or User policy by reading first line
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

    # Create temp directory
    if (-not (Test-Path $tempPath)) {
        New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
    }

    # Process Computer policies
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

    # Process User policies
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

    # Cleanup temp files
    Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
}

# Main execution
Write-Output "=== Windows 11 Policy Application ==="
Write-Output ""

# Validate parameters (install.ps1 already validates values, just check presence)
if (-not $systemPurpose -or -not $systemOwnership) {
    throw "Both 'systemPurpose' and 'systemOwnership' parameters must be provided."
}

$systemPurpose = $systemPurpose.ToLower()
$systemOwnership = $systemOwnership.ToLower()

# Verify LGPO.exe exists
if (-not (Test-Path $lgpoPath)) {
    throw "LGPO.exe not found at $lgpoPath"
}

# Verify config exists
if (-not (Test-Path $configPath)) {
    throw "Policy configuration not found at $configPath"
}

Write-Output "Purpose: $systemPurpose"
Write-Output "Ownership: $systemOwnership"
Write-Output ""

# Download wallpaper for shared and personal systems
if ($systemOwnership -eq "shared" -or $systemOwnership -eq "personal") {
    $wallpaperUrl = "https://www.zuidwestupdate.nl/wp-content/uploads/2021/03/voorpagina-placeholder.png"
    $wallpaperDir = "C:\ProgramData\ZuidWest\wallpaper"
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

# Load configuration
$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Get applicable policies
$applicablePolicies = Get-ApplicablePolicies -config $config -purpose $systemPurpose -ownership $systemOwnership

$totalPolicies = $applicablePolicies.Computer.Count + $applicablePolicies.User.Count

if ($totalPolicies -eq 0) {
    Write-Output "`nNo applicable policies found for this configuration."
    return
}

Write-Output "`nFound $totalPolicies applicable policies"

# Apply policies
Set-Policy -policies $applicablePolicies

Write-Output "`n=== Policy application complete ==="

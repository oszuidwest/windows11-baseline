param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName
)

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
$deployPath = "C:\Windows\deploy"
$lgpoPath = Join-Path $deployPath "LGPO.exe"
$policiesPath = Join-Path $deployPath "policies"
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
                Write-Output "  [+] $policyPath"
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

    $content = @()
    foreach ($file in $policyFiles) {
        $content += Get-Content $file -Raw
        $content += "`n"
    }

    $content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline
}

function Apply-Policies {
    param (
        [hashtable]$policies
    )

    # Create temp directory
    if (-not (Test-Path $tempPath)) {
        New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
    }

    # Process Computer policies
    if ($policies.Computer.Count -gt 0) {
        Write-Output "`nApplying $($policies.Computer.Count) computer policies..."

        $computerTxt = Join-Path $tempPath "computer.txt"
        $computerPol = Join-Path $tempPath "computer.pol"

        Merge-PolicyFiles -policyFiles $policies.Computer -outputPath $computerTxt

        # Convert txt to pol
        & $lgpoPath /r $computerTxt /w $computerPol 2>&1 | Out-Null

        # Apply to machine
        & $lgpoPath /m $computerPol

        Write-Output "  Computer policies applied successfully"
    }

    # Process User policies
    if ($policies.User.Count -gt 0) {
        Write-Output "`nApplying $($policies.User.Count) user policies (non-admin accounts)..."

        $userTxt = Join-Path $tempPath "user.txt"
        $userPol = Join-Path $tempPath "user.pol"

        Merge-PolicyFiles -policyFiles $policies.User -outputPath $userTxt

        # Convert txt to pol
        & $lgpoPath /r $userTxt /w $userPol 2>&1 | Out-Null

        # Apply to non-administrator accounts only
        & $lgpoPath /un $userPol

        Write-Output "  User policies applied successfully"
    }

    # Cleanup temp files
    Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
}

# Main execution
Write-Output "=== Windows 11 Policy Application ==="
Write-Output ""

# Validate parameters
if (-not $systemPurpose -or -not $systemOwnership) {
    Write-Error "Both 'systemPurpose' and 'systemOwnership' parameters must be provided."
    exit 1
}

$systemPurpose = $systemPurpose.ToLower()
$systemOwnership = $systemOwnership.ToLower()

$validPurposes = @("radio", "tv", "editorial", "plain")
$validOwnership = @("shared", "personal", "dedicated")

if ($systemPurpose -notin $validPurposes) {
    Write-Error "Invalid systemPurpose: $systemPurpose. Must be one of: $($validPurposes -join ', ')"
    exit 1
}

if ($systemOwnership -notin $validOwnership) {
    Write-Error "Invalid systemOwnership: $systemOwnership. Must be one of: $($validOwnership -join ', ')"
    exit 1
}

# Verify LGPO.exe exists
if (-not (Test-Path $lgpoPath)) {
    Write-Error "LGPO.exe not found at $lgpoPath"
    exit 1
}

# Verify config exists
if (-not (Test-Path $configPath)) {
    Write-Error "Policy configuration not found at $configPath"
    exit 1
}

Write-Output "Purpose: $systemPurpose"
Write-Output "Ownership: $systemOwnership"
Write-Output ""
Write-Output "Finding applicable policies..."

# Load configuration
$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Get applicable policies
$applicablePolicies = Get-ApplicablePolicies -config $config -purpose $systemPurpose -ownership $systemOwnership

$totalPolicies = $applicablePolicies.Computer.Count + $applicablePolicies.User.Count

if ($totalPolicies -eq 0) {
    Write-Output "`nNo applicable policies found for this configuration."
    exit 0
}

Write-Output "`nFound $totalPolicies applicable policies"

# Apply policies
Apply-Policies -policies $applicablePolicies

Write-Output "`n=== Policy application complete ==="

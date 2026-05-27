param (
    [string]$systemOwnership
)

. (Join-Path $PSScriptRoot "_common.ps1")

<#
.SYNOPSIS
    Applies AppLocker policies to block unwanted applications.

.DESCRIPTION
    This script applies a checked-in AppLocker policy template based on system ownership:

    Shared systems (policies/applocker/shared.xml):
    - Blocks Microsoft Store application
    - Blocks Microsoft Copilot application
    - Blocks StoreInstaller.exe (web installer from get.microsoft.com)

    Dedicated systems (policies/applocker/dedicated.xml):
    - Blocks Microsoft Copilot application only
    - Microsoft Store appx is still removed via the debloat phase

    Personal systems: No AppLocker policies applied.

    Prerequisites:
    - Windows Enterprise or Education edition (LTSC qualifies)
    - Application Identity service must be running

.PARAMETER systemOwnership
    The ownership type: "shared", "personal", or "dedicated"
#>

# Paths
$appLockerToolPath = Join-DeployPath "bin\AppLockerPolicyTool.exe"
$appLockerTemplateDir = Join-DeployPath "policies\applocker"

Write-Output "=== AppLocker Configuration ==="
Write-Output ""

# Select template based on ownership
switch ($systemOwnership) {
    "shared" {
        $templateName = "shared.xml"
        $policyDescription = "Store + Copilot + StoreInstaller.exe"
    }
    "dedicated" {
        $templateName = "dedicated.xml"
        $policyDescription = "Copilot only"
    }
    default {
        Write-Output "Skipping AppLocker configuration (only applies to shared/dedicated systems)"
        Write-Output "Current ownership: $systemOwnership"
        return
    }
}

$templatePath = Join-Path $appLockerTemplateDir $templateName

Write-Output "Ownership: $systemOwnership"
Write-Output "Template: $templateName"
Write-Output "Blocks: $policyDescription"
Write-Output ""

if (-not (Test-Path $appLockerToolPath)) {
    throw "AppLockerPolicyTool.exe not found at $appLockerToolPath"
}

if (-not (Test-Path $templatePath)) {
    throw "AppLocker template not found at $templatePath"
}

# Step 1: Enable and start the Application Identity service
Write-Output "Enabling Application Identity service (AppIdSvc)..."

$service = Get-Service -Name "AppIDSvc" -ErrorAction SilentlyContinue
if (-not $service) {
    throw "AppIDSvc service not present on this system. AppLocker cannot be enforced without it (requires Windows Enterprise/Education/LTSC)."
}

Invoke-NativeCommand -FilePath "sc.exe" `
    -Arguments @("config", "AppIDSvc", "start=", "auto") `
    -FailureMessage "Failed to set AppIDSvc startup type to Automatic" | Out-Null
Write-Output "  Service startup type set to Automatic"

if ($service.Status -ne "Running") {
    Invoke-NativeCommand -FilePath "sc.exe" `
        -Arguments @("start", "AppIDSvc") `
        -FailureMessage "Failed to start AppIDSvc" | Out-Null

    $deadline = (Get-Date).AddSeconds(30)
    do {
        Start-Sleep -Seconds 2
        $service = Get-Service -Name "AppIDSvc"
    } while ($service.Status -ne "Running" -and (Get-Date) -lt $deadline)

    if ($service.Status -ne "Running") {
        throw "AppIDSvc did not reach Running state within 30 seconds (current status: $($service.Status)). AppLocker rules would not be enforced."
    }
    Write-Output "  Service started successfully"
}
else {
    Write-Output "  Service is already running"
}

Write-Output ""

# Step 2: Apply AppLocker policy template
Write-Output "Applying AppLocker policy from $templateName..."

try {
    Invoke-NativeCommand -FilePath $appLockerToolPath `
        -Arguments @("-lgpo", "-set", $templatePath) `
        -FailureMessage "AppLockerPolicyTool failed" | Out-Null
    Write-Output "  AppLocker policy applied successfully"
}
catch {
    throw "Failed to apply AppLocker policy: $($_.Exception.Message)"
}

Write-Output ""

# Step 3: Verify policy was applied
Write-Output "Verifying AppLocker policy..."

try {
    $policy = Get-AppLockerPolicy -Local -ErrorAction Stop
}
catch {
    throw "Could not read back local AppLocker policy after apply: $($_.Exception.Message)"
}

if (-not $policy -or -not $policy.RuleCollections) {
    throw "Local AppLocker policy is empty after apply; enforcement would silently no-op."
}

$exeRules = $policy.RuleCollections | Where-Object { $_.RuleCollectionType -eq "Exe" }
$appxRules = $policy.RuleCollections | Where-Object { $_.RuleCollectionType -eq "Appx" }
$exeRuleCount = if ($exeRules) { ($exeRules | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum } else { 0 }
$appxRuleCount = if ($appxRules) { ($appxRules | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum } else { 0 }

Write-Output "  Executable rules: $exeRuleCount"
Write-Output "  Packaged app rules: $appxRuleCount"

if ($exeRuleCount -eq 0 -or $appxRuleCount -eq 0) {
    throw "AppLocker policy applied but rule counts are empty (Exe=$exeRuleCount, Appx=$appxRuleCount); enforcement would silently no-op."
}

$managedCollections = @($policy.RuleCollections | Where-Object { $_.RuleCollectionType -in @("Exe", "Appx") })
$nonEnforced = @($managedCollections | Where-Object { $_.EnforcementMode -ne "Enabled" })
if ($nonEnforced.Count -gt 0) {
    $modes = ($nonEnforced | ForEach-Object { "$($_.RuleCollectionType)=$($_.EnforcementMode)" }) -join ", "
    throw "AppLocker rule collections not in Enabled enforcement mode: $modes. Rules would log but not block."
}

Write-Output ""
Write-Output "=== AppLocker configuration complete ==="
Write-Output ""
Write-Output "The following are now blocked for non-admin users:"
if ($systemOwnership -eq "shared") {
    Write-Output "  - Microsoft Store application"
    Write-Output "  - StoreInstaller.exe (web installer from get.microsoft.com)"
}
Write-Output "  - Microsoft Copilot application"

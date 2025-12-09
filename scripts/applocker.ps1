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
    Applies AppLocker policies to block Microsoft Store installations on shared systems.

.DESCRIPTION
    This script configures AppLocker to prevent users from:
    - Running the Microsoft Store application
    - Installing apps via StoreInstaller.exe (the web installer from get.microsoft.com)

    The policy only applies to shared systems where users should not install applications.

    Prerequisites:
    - Windows Enterprise or Education edition (LTSC qualifies)
    - Application Identity service must be running

.PARAMETER systemOwnership
    The ownership type: "shared", "personal", or "dedicated"
    AppLocker policies are only applied to "shared" systems.
#>

# Paths
$deployPath = "C:\Windows\deploy"
$appLockerToolPath = Join-Path $deployPath "bin\AppLockerPolicyTool.exe"
$appLockerPolicyPath = Join-Path $deployPath "policies\applocker\block-store-installs.xml"

Write-Output "=== AppLocker Configuration ==="
Write-Output ""

# Only apply to shared systems
if ($systemOwnership -ne "shared") {
    Write-Output "Skipping AppLocker configuration (only applies to shared systems)"
    Write-Output "Current ownership: $systemOwnership"
    exit 0
}

Write-Output "Ownership: $systemOwnership"
Write-Output "Configuring AppLocker to block Store installations..."
Write-Output ""

# Verify AppLockerPolicyTool.exe exists
if (-not (Test-Path $appLockerToolPath)) {
    Write-Error "AppLockerPolicyTool.exe not found at $appLockerToolPath"
    exit 1
}

# Verify policy file exists
if (-not (Test-Path $appLockerPolicyPath)) {
    Write-Error "AppLocker policy not found at $appLockerPolicyPath"
    exit 1
}

# Step 1: Enable and start the Application Identity service
Write-Output "Enabling Application Identity service (AppIdSvc)..."

try {
    # Set service to start automatically
    Set-Service -Name "AppIDSvc" -StartupType Automatic -ErrorAction Stop
    Write-Output "  Service startup type set to Automatic"

    # Start the service if not running
    $service = Get-Service -Name "AppIDSvc"
    if ($service.Status -ne "Running") {
        Start-Service -Name "AppIDSvc" -ErrorAction Stop
        Write-Output "  Service started successfully"
    }
    else {
        Write-Output "  Service is already running"
    }
}
catch {
    Write-Warning "Failed to configure AppIdSvc service: $_"
    Write-Warning "AppLocker policies may not be enforced without this service"
}

Write-Output ""

# Step 2: Apply AppLocker policy
Write-Output "Applying AppLocker policy..."

try {
    $result = & $appLockerToolPath -lgpo -set $appLockerPolicyPath 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Output "  AppLocker policy applied successfully"
    }
    else {
        Write-Warning "AppLockerPolicyTool returned exit code: $LASTEXITCODE"
        Write-Warning "Output: $result"
    }
}
catch {
    Write-Error "Failed to apply AppLocker policy: $_"
    exit 1
}

Write-Output ""

# Step 3: Verify policy was applied
Write-Output "Verifying AppLocker policy..."

try {
    $policy = Get-AppLockerPolicy -Local -ErrorAction Stop
    $exeRuleCount = ($policy.RuleCollections | Where-Object { $_.RuleCollectionType -eq "Exe" }).Count
    $appxRuleCount = ($policy.RuleCollections | Where-Object { $_.RuleCollectionType -eq "Appx" }).Count

    Write-Output "  Policy loaded successfully"
    Write-Output "  Executable rule collections: $exeRuleCount"
    Write-Output "  Packaged app rule collections: $appxRuleCount"
}
catch {
    Write-Warning "Could not verify policy: $_"
}

Write-Output ""
Write-Output "=== AppLocker configuration complete ==="
Write-Output ""
Write-Output "The following are now blocked for non-admin users:"
Write-Output "  - Microsoft Store application"
Write-Output "  - StoreInstaller.exe (web installer from get.microsoft.com)"

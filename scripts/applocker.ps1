param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName,
    [string]$dwAgentCode,
    [string]$dedicatedUserName
)

<#
.SYNOPSIS
    Applies AppLocker policies to block unwanted applications.

.DESCRIPTION
    This script dynamically generates and applies AppLocker policies based on system ownership:

    Shared systems:
    - Blocks Microsoft Store application
    - Blocks Microsoft Copilot application
    - Blocks StoreInstaller.exe (web installer from get.microsoft.com)

    Dedicated systems:
    - Blocks Microsoft Copilot application only
    - Microsoft Store remains available

    Personal systems: No AppLocker policies applied.

    Prerequisites:
    - Windows Enterprise or Education edition (LTSC qualifies)
    - Application Identity service must be running

.PARAMETER systemOwnership
    The ownership type: "shared", "personal", or "dedicated"
#>

# Paths
$deployPath = "C:\Windows\deploy"
$appLockerToolPath = Join-Path $deployPath "bin\AppLockerPolicyTool.exe"
$appLockerPolicyPath = Join-Path $deployPath "policies\applocker\policy.xml"

Write-Output "=== AppLocker Configuration ==="
Write-Output ""

# Determine what to block based on ownership
switch ($systemOwnership) {
    "shared" {
        $blockStore = $true
        $blockCopilot = $true
        $policyDescription = "Store + Copilot"
    }
    "dedicated" {
        $blockStore = $false
        $blockCopilot = $true
        $policyDescription = "Copilot only"
    }
    default {
        Write-Output "Skipping AppLocker configuration (only applies to shared/dedicated systems)"
        Write-Output "Current ownership: $systemOwnership"
        exit 0
    }
}

Write-Output "Ownership: $systemOwnership"
Write-Output "Configuring AppLocker to block: $policyDescription"
Write-Output ""

# Verify AppLockerPolicyTool.exe exists
if (-not (Test-Path $appLockerToolPath)) {
    Write-Error "AppLockerPolicyTool.exe not found at $appLockerToolPath"
    exit 1
}

# Generate AppLocker policy XML dynamically
function New-AppLockerPolicy {
    param (
        [bool]$BlockStore,
        [bool]$BlockCopilot
    )

    # Build executable deny rules
    $exeDenyRules = ""
    if ($BlockStore) {
        $exeDenyRules = @"

        <!-- DENY: Block StoreInstaller.exe (the Microsoft Store web installer) -->
        <FilePublisherRule Id="b7d74306-35f3-4ad6-a29f-796e2491c992"
                           Name="Block StoreInstaller.exe"
                           Description="Blocks the Microsoft Store web installer downloaded from get.microsoft.com"
                           UserOrGroupSid="S-1-1-0"
                           Action="Deny">
            <Conditions>
                <FilePublisherCondition PublisherName="O=MICROSOFT CORPORATION, L=REDMOND, S=WASHINGTON, C=US"
                                        ProductName="STOREINSTALLER"
                                        BinaryName="STOREINSTALLER.EXE">
                    <BinaryVersionRange LowSection="*" HighSection="*"/>
                </FilePublisherCondition>
            </Conditions>
        </FilePublisherRule>
"@
    }

    # Build packaged app deny rules
    $appxDenyRules = ""
    if ($BlockStore) {
        $appxDenyRules += @"

        <!-- DENY: Block Microsoft Store app -->
        <FilePublisherRule Id="a0a3fca2-3820-4489-8db0-4e2fc319b756"
                           Name="Block Microsoft Store"
                           Description="Prevents users from opening the Microsoft Store application"
                           UserOrGroupSid="S-1-1-0"
                           Action="Deny">
            <Conditions>
                <FilePublisherCondition PublisherName="CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US"
                                        ProductName="Microsoft.WindowsStore"
                                        BinaryName="*">
                    <BinaryVersionRange LowSection="*" HighSection="*"/>
                </FilePublisherCondition>
            </Conditions>
        </FilePublisherRule>
"@
    }

    if ($BlockCopilot) {
        $appxDenyRules += @"

        <!-- DENY: Block Microsoft Copilot app -->
        <FilePublisherRule Id="c8d91a3b-5927-4f8a-9c1e-3b6d82f4a509"
                           Name="Block Microsoft Copilot"
                           Description="Prevents users from opening the Microsoft Copilot application"
                           UserOrGroupSid="S-1-1-0"
                           Action="Deny">
            <Conditions>
                <FilePublisherCondition PublisherName="CN=MICROSOFT CORPORATION, O=MICROSOFT CORPORATION, L=REDMOND, S=WASHINGTON, C=US"
                                        ProductName="MICROSOFT.COPILOT"
                                        BinaryName="*">
                    <BinaryVersionRange LowSection="*" HighSection="*"/>
                </FilePublisherCondition>
            </Conditions>
        </FilePublisherRule>
"@
    }

    # Generate the full policy XML
    $policyXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<AppLockerPolicy Version="1">

    <!-- EXECUTABLE RULES -->
    <RuleCollection Type="Exe" EnforcementMode="Enabled">

        <!-- Default Rule: Allow Windows folder executables for Everyone -->
        <FilePathRule Id="a61c8b2c-a319-4cd0-9690-d2177cad7b51"
                      Name="(Default) Allow Windows folder"
                      Description="Allows everyone to run applications in the Windows folder"
                      UserOrGroupSid="S-1-1-0"
                      Action="Allow">
            <Conditions>
                <FilePathCondition Path="%WINDIR%\*"/>
            </Conditions>
        </FilePathRule>

        <!-- Default Rule: Allow Program Files executables for Everyone -->
        <FilePathRule Id="921cc481-6e17-4653-8f75-050b80acca20"
                      Name="(Default) Allow Program Files"
                      Description="Allows everyone to run applications in Program Files"
                      UserOrGroupSid="S-1-1-0"
                      Action="Allow">
            <Conditions>
                <FilePathCondition Path="%PROGRAMFILES%\*"/>
            </Conditions>
        </FilePathRule>

        <!-- Default Rule: Allow Administrators to run anything -->
        <FilePathRule Id="fd686d83-a829-4351-8ff4-27c7de5755d2"
                      Name="(Default) Allow Administrators"
                      Description="Allows administrators to run all applications"
                      UserOrGroupSid="S-1-5-32-544"
                      Action="Allow">
            <Conditions>
                <FilePathCondition Path="*"/>
            </Conditions>
        </FilePathRule>
$exeDenyRules
    </RuleCollection>

    <!-- PACKAGED APP (APPX/MSIX) RULES -->
    <RuleCollection Type="Appx" EnforcementMode="Enabled">

        <!-- Default Rule: Allow all signed packaged apps for Everyone -->
        <FilePublisherRule Id="a9e18c21-ff8f-43cf-b9fc-db40eed693ba"
                           Name="(Default) Allow all signed packaged apps"
                           Description="Allows everyone to run all signed packaged applications"
                           UserOrGroupSid="S-1-1-0"
                           Action="Allow">
            <Conditions>
                <FilePublisherCondition PublisherName="*" ProductName="*" BinaryName="*">
                    <BinaryVersionRange LowSection="0.0.0.0" HighSection="*"/>
                </FilePublisherCondition>
            </Conditions>
        </FilePublisherRule>
$appxDenyRules
    </RuleCollection>

</AppLockerPolicy>
"@

    return $policyXml
}

# Generate and save the policy
Write-Output "Generating AppLocker policy..."
$policyXml = New-AppLockerPolicy -BlockStore $blockStore -BlockCopilot $blockCopilot

# Ensure the applocker directory exists
$appLockerDir = Split-Path $appLockerPolicyPath -Parent
if (-not (Test-Path $appLockerDir)) {
    New-Item -ItemType Directory -Path $appLockerDir -Force | Out-Null
}

# Save the policy to a file
$policyXml | Out-File -FilePath $appLockerPolicyPath -Encoding UTF8 -Force
Write-Output "  Policy saved to: $appLockerPolicyPath"
Write-Output ""

# Step 1: Enable and start the Application Identity service
Write-Output "Enabling Application Identity service (AppIdSvc)..."

try {
    # Set service to start automatically using sc.exe (more reliable than Set-Service)
    $scResult = & sc.exe config AppIDSvc start= auto 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Output "  Service startup type set to Automatic"
    }
    else {
        Write-Warning "Failed to set service startup type: $scResult"
    }

    # Start the service if not running
    $service = Get-Service -Name "AppIDSvc" -ErrorAction SilentlyContinue
    if ($service -and $service.Status -ne "Running") {
        & sc.exe start AppIDSvc | Out-Null
        Start-Sleep -Seconds 2
        $service = Get-Service -Name "AppIDSvc"
        if ($service.Status -eq "Running") {
            Write-Output "  Service started successfully"
        }
        else {
            Write-Warning "Service may not have started. Status: $($service.Status)"
        }
    }
    elseif ($service) {
        Write-Output "  Service is already running"
    }
    else {
        Write-Warning "AppIDSvc service not found"
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
if ($blockStore) {
    Write-Output "  - Microsoft Store application"
    Write-Output "  - StoreInstaller.exe (web installer from get.microsoft.com)"
}
if ($blockCopilot) {
    Write-Output "  - Microsoft Copilot application"
}

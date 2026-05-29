<#
.SYNOPSIS
    Shared helpers for Windows 11 baseline deployment scripts.
#>

$script:DeploymentMinimumPasswordLength = 14

function Get-ZuidWestRoot {
    return (Join-Path $env:ProgramData "ZuidWest")
}

function Join-ZuidWestPath {
    param (
        [Parameter(Mandatory, Position = 0)]
        [string[]]$ChildPath
    )

    $path = Get-ZuidWestRoot
    foreach ($child in $ChildPath) {
        $path = Join-Path $path $child
    }
    return $path
}

function Get-DeployPath {
    if ($env:WINDOWS11_BASELINE_DEPLOY_PATH) {
        return $env:WINDOWS11_BASELINE_DEPLOY_PATH
    }

    return (Join-ZuidWestPath "deploy")
}

function Join-DeployPath {
    param (
        [Parameter(Mandatory, Position = 0)]
        [string[]]$ChildPath
    )

    $path = Get-DeployPath
    foreach ($child in $ChildPath) {
        $path = Join-Path $path $child
    }
    return $path
}

function ConvertTo-CmdArgument {
    param (
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Argument
    )

    if ($Argument -eq "") {
        return '""'
    }

    if ($Argument -match '[\s&()^|<>"]') {
        return '"' + ($Argument -replace '"', '\"') + '"'
    }

    return $Argument
}

function Invoke-NativeCommand {
    param (
        [Parameter(Mandatory)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [int[]]$SuccessExitCodes = @(0),

        [string]$FailureMessage = "Native command failed",

        [switch]$PassThru
    )

    $argumentLine = ($Arguments | ForEach-Object { ConvertTo-CmdArgument $_ }) -join " "
    $commandLine = "call $(ConvertTo-CmdArgument $FilePath) $argumentLine 2>&1".Trim()
    $output = cmd.exe /d /c $commandLine
    $exitCode = $LASTEXITCODE

    if ($SuccessExitCodes -notcontains $exitCode) {
        if ($output) {
            $output | Write-Output
        }
        throw "$FailureMessage with exit code $exitCode"
    }

    if ($PassThru) {
        return [pscustomobject]@{
            ExitCode = $exitCode
            Output   = $output
        }
    }

    if ($output) {
        $output | Write-Output
    }
}

function Invoke-Download {
    param (
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [string]$OutFile
    )

    $parentPath = Split-Path $OutFile -Parent
    if ($parentPath -and -not (Test-Path $parentPath)) {
        New-Item -Path $parentPath -ItemType Directory -Force | Out-Null
    }

    $previousProgressPreference = $ProgressPreference
    try {
        $ProgressPreference = "SilentlyContinue"
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
    }
    finally {
        $ProgressPreference = $previousProgressPreference
    }
}

function Save-DeploymentStateAtomic {
    <#
    .SYNOPSIS
        Atomically write JSON state with one .bak generation.

    .DESCRIPTION
        Writes to "$Path.tmp", swaps it into place with File.Replace when
        possible, and keeps "$Path.bak" for read fallback.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        $State
    )

    if (-not $PSCmdlet.ShouldProcess($Path, "Atomic state write")) {
        return
    }

    $tmpPath = "$Path.tmp"
    $bakPath = "$Path.bak"
    $State | ConvertTo-Json -Depth 6 | Set-Content -Path $tmpPath -Encoding UTF8 -Force
    if (Test-Path $Path) {
        [System.IO.File]::Replace($tmpPath, $Path, $bakPath)
    }
    else {
        Move-Item -Path $tmpPath -Destination $Path -Force
    }
}

function Read-DeploymentState {
    <#
    .SYNOPSIS
        Read JSON state, falling back to .bak if the main file is corrupt.

    .DESCRIPTION
        If both generations fail, the original parse exception is rethrown.
    #>
    [OutputType([object])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        return Get-Content -Path $Path -Raw | ConvertFrom-Json
    }
    catch {
        $bakPath = "$Path.bak"
        if (Test-Path $bakPath) {
            Write-Warning "State file at $Path appears corrupt; falling back to $bakPath"
            return Get-Content -Path $bakPath -Raw | ConvertFrom-Json
        }
        throw
    }
}

function Assert-BundledBinary {
    <#
    .SYNOPSIS
        Verify a bundled binary before invocation.

    .DESCRIPTION
        Checks SHA-256 from bin/hashes.json and a valid Microsoft Authenticode
        signature. Get-DeployPath supports staged auto-update copies.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$BinaryPath
    )

    if (-not (Test-Path $BinaryPath)) {
        throw "Bundled binary not found at $BinaryPath"
    }

    $manifestPath = Join-DeployPath "bin", "hashes.json"
    if (-not (Test-Path $manifestPath)) {
        throw "Bundled binary manifest not found at $manifestPath. Refusing to run an unverified binary."
    }

    $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
    if (-not $manifest.binaries) {
        throw "Bundled binary manifest at $manifestPath is missing a 'binaries' object."
    }

    $binaryName = Split-Path -Path $BinaryPath -Leaf
    $expected = $manifest.binaries.$binaryName
    if (-not $expected) {
        throw "No expected SHA-256 declared for '$binaryName' in $manifestPath. Add it in the same commit as the binary bump."
    }

    $actual = (Get-FileHash -Path $BinaryPath -Algorithm SHA256).Hash
    if (-not $actual.Equals($expected, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "SHA-256 mismatch for '$binaryName' (expected $expected, got $actual). Refusing to invoke."
    }

    if (-not (Get-Command Get-AuthenticodeSignature -ErrorAction SilentlyContinue)) {
        throw "Get-AuthenticodeSignature is not available. Refusing to invoke '$binaryName' without validating its Microsoft signature."
    }

    $signature = Get-AuthenticodeSignature -FilePath $BinaryPath
    if ($signature.Status -ne "Valid") {
        throw "Authenticode signature for '$binaryName' is not valid (status: $($signature.Status)). Refusing to invoke."
    }

    $subject = $signature.SignerCertificate.Subject
    if ($subject -notmatch "Microsoft Corporation") {
        throw "Authenticode signature for '$binaryName' was not issued to Microsoft Corporation (subject: $subject). Refusing to invoke."
    }
}

function Get-ScriptParameterNames {
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors) {
        throw "PowerShell parse errors in $($Path): $($parseErrors -join '; ')"
    }
    if (-not $ast.ParamBlock) {
        return @()
    }
    return @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
}

function ConvertFrom-SecureStringToPlainText {
    param (
        [Parameter(Mandatory)]
        [securestring]$SecureString
    )

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Test-LocalUserPassword {
    param (
        [Parameter(Mandatory)]
        [securestring]$SecurePassword,

        [Parameter(Mandatory)]
        [string]$AccountName
    )

    $plainPassword = ConvertFrom-SecureStringToPlainText -SecureString $SecurePassword

    if ([string]::IsNullOrWhiteSpace($plainPassword)) {
        throw "A password is required when creating '$AccountName'."
    }

    if ($plainPassword.Length -lt $script:DeploymentMinimumPasswordLength) {
        throw "The password for '$AccountName' must be at least $script:DeploymentMinimumPasswordLength characters."
    }

    $characterClasses = 0
    if ($plainPassword -cmatch "[A-Z]") { $characterClasses++ }
    if ($plainPassword -cmatch "[a-z]") { $characterClasses++ }
    if ($plainPassword -match "\d") { $characterClasses++ }
    if ($plainPassword -match "[^a-zA-Z\d]") { $characterClasses++ }

    if ($characterClasses -lt 3) {
        throw "The password for '$AccountName' must contain characters from at least 3 of these groups: uppercase, lowercase, numbers, symbols."
    }

    $userNameParts = @($AccountName -split "[\s._-]+" | Where-Object { $_.Length -ge 3 })
    foreach ($userNamePart in $userNameParts) {
        if ($plainPassword.IndexOf($userNamePart, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            throw "The password for '$AccountName' must not contain username part '$userNamePart'."
        }
    }
}

function Resolve-DeploymentUserName {
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$SystemPurpose,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$SystemOwnership,

        [AllowEmptyString()]
        [string]$DedicatedUserName,

        [AllowEmptyString()]
        [string]$PersonalUserName
    )

    $purpose = $SystemPurpose.ToLower()
    $ownership = $SystemOwnership.ToLower()

    if ($ownership -eq "dedicated" -and $DedicatedUserName) {
        return [pscustomobject]@{ UserName = $DedicatedUserName; EnableAutoLogin = $true }
    }

    if ($ownership -eq "personal" -and $PersonalUserName) {
        return [pscustomobject]@{ UserName = $PersonalUserName; EnableAutoLogin = $false }
    }

    if ($ownership -eq "shared") {
        $sharedUserNames = @{
            'editorial' = 'Redactie Gebruiker'
            'tv'        = 'Studio Gebruiker'
            'radio'     = 'Studio Gebruiker'
        }
        $sharedUserName = $sharedUserNames[$purpose]
        if (-not $sharedUserName) { $sharedUserName = "" }
        return [pscustomobject]@{ UserName = $sharedUserName; EnableAutoLogin = ($purpose -ne "plain") }
    }

    return [pscustomobject]@{ UserName = ""; EnableAutoLogin = $false }
}

function Read-DeploymentPassword {
    param (
        [Parameter(Mandatory)]
        [string]$AccountName,

        [string]$Prompt = "Enter the user password"
    )

    Write-Host "Password requirements for '$AccountName':"
    Write-Host "  - At least $script:DeploymentMinimumPasswordLength characters"
    Write-Host "  - Characters from at least 3 of: uppercase, lowercase, numbers, symbols"
    Write-Host "  - Must not contain parts of the username"

    while ($true) {
        $securePassword = Read-Host -Prompt $Prompt -AsSecureString
        try {
            Test-LocalUserPassword -SecurePassword $securePassword -AccountName $AccountName
            return $securePassword
        }
        catch {
            Write-Warning $_.Exception.Message
            Write-Host ""
        }
    }
}

# WUA orcSucceeded == 2. See https://learn.microsoft.com/en-us/windows/win32/api/wuapi/ne-wuapi-operationresultcode
$script:WuaSucceededCode = 2

function Test-WuaSucceeded {
    param (
        [Parameter(Mandatory)]
        [int]$ResultCode
    )
    return $ResultCode -eq $script:WuaSucceededCode
}

function Get-WuaOperationResultName {
    param (
        [Parameter(Mandatory)]
        [int]$ResultCode
    )

    $resultCodeNames = @{
        0 = 'NotStarted'
        1 = 'InProgress'
        2 = 'Succeeded'
        3 = 'SucceededWithErrors'
        4 = 'Failed'
        5 = 'Aborted'
    }

    $resultName = $resultCodeNames[$ResultCode]
    if (-not $resultName) {
        return "Unknown($ResultCode)"
    }
    return $resultName
}

function Get-WuaFailedUpdateDetails {
    param (
        [Parameter(Mandatory)]
        $OperationResult,

        [Parameter(Mandatory)]
        $Updates
    )

    $failedUpdates = [System.Collections.Generic.List[string]]::new()
    for ($idx = 0; $idx -lt $Updates.Count; $idx++) {
        $perUpdateResult = $OperationResult.GetUpdateResult($idx)
        $perUpdateCode = [int]$perUpdateResult.ResultCode
        if (-not (Test-WuaSucceeded -ResultCode $perUpdateCode)) {
            $hresult = "0x{0:X8}" -f ([int]$perUpdateResult.HResult)
            $title = $Updates.Item($idx).Title
            $perUpdateName = Get-WuaOperationResultName -ResultCode $perUpdateCode
            $failedUpdates.Add("  - $title ($perUpdateName, HRESULT $hresult)")
        }
    }

    return $failedUpdates.ToArray()
}

function Assert-WuaOperationSucceeded {
    param (
        [Parameter(Mandatory)]
        $OperationResult,

        [Parameter(Mandatory)]
        $Updates,

        [Parameter(Mandatory)]
        [ValidateSet('Download', 'Install')]
        [string]$Phase
    )

    $code = [int]$OperationResult.ResultCode
    $name = Get-WuaOperationResultName -ResultCode $code
    Write-Output "  $Phase operation result: $name ($code)"

    if (Test-WuaSucceeded -ResultCode $code) {
        return
    }

    $failedUpdates = Get-WuaFailedUpdateDetails -OperationResult $OperationResult -Updates $Updates
    $detail = if ($failedUpdates.Count -gt 0) { "`n" + ($failedUpdates -join "`n") } else { "" }
    throw "Windows Update $($Phase.ToLower()) reported $name ($code).$detail"
}

# Child scripts suspend the parent transcript around plaintext secrets.
function Suspend-InstallTranscript {
    if (-not $env:WINDOWS11_BASELINE_TRANSCRIPT_PATH) {
        return $false
    }
    try {
        Stop-Transcript | Out-Null
        return $true
    }
    catch {
        throw "Could not suspend transcript before sensitive operation: $($_.Exception.Message)"
    }
}

function Resume-InstallTranscript {
    param (
        [Parameter(Mandatory)]
        [bool]$WasSuspended
    )

    if (-not $WasSuspended -or -not $env:WINDOWS11_BASELINE_TRANSCRIPT_PATH) {
        return
    }

    try {
        Start-Transcript -Path $env:WINDOWS11_BASELINE_TRANSCRIPT_PATH -Append -Force | Out-Null
    }
    catch {
        Write-Warning "Could not resume transcript logging: $($_.Exception.Message)"
    }
}

function Invoke-WithTranscriptSuspended {
    param (
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $wasSuspended = Suspend-InstallTranscript
    try {
        & $ScriptBlock
    }
    finally {
        Resume-InstallTranscript -WasSuspended $wasSuspended
    }
}

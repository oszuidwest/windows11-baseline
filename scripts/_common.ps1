<#
.SYNOPSIS
    Shared helpers for Windows 11 baseline deployment scripts.
#>

function Get-DeployPath {
    if ($env:WINDOWS11_BASELINE_DEPLOY_PATH) {
        return $env:WINDOWS11_BASELINE_DEPLOY_PATH
    }

    return "C:\Windows\deploy"
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

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
    return (New-Object Security.Principal.WindowsPrincipal $currentUser).IsInRole($adminRole)
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

function Get-ScriptParameterNames {
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$parseErrors)
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

    if ($plainPassword.Length -lt 8) {
        throw "The password for '$AccountName' must be at least 8 characters."
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

    Write-Output "Password requirements for '$AccountName':"
    Write-Output "  - At least 8 characters"
    Write-Output "  - Characters from at least 3 of: uppercase, lowercase, numbers, symbols"
    Write-Output "  - Must not contain parts of the username"

    while ($true) {
        $securePassword = Read-Host -Prompt $Prompt -AsSecureString
        try {
            Test-LocalUserPassword -SecurePassword $securePassword -AccountName $AccountName
            return $securePassword
        }
        catch {
            Write-Warning $_.Exception.Message
            Write-Output ""
        }
    }
}

# WUA orcSucceeded == 2. See https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-wsusss/0a8c5b85-2123-4ed9-a6cd-7d23e23e3786
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

# install.ps1 publishes the active transcript path to $env:WINDOWS11_BASELINE_TRANSCRIPT_PATH;
# child scripts (invoked via &) read it to suspend/resume the parent transcript around plaintext
# secrets (e.g. registry writes that would otherwise be captured).
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

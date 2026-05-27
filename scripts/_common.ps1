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

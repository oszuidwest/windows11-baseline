param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [securestring]$userPassword,
    [string]$dedicatedUserName,
    [string]$personalUserName
)

. (Join-Path $PSScriptRoot "_common.ps1")

Write-Output "Configuring user settings..."

function ConvertTo-FriendlyPasswordError {
    param (
        [Parameter(Mandatory)]
        $ErrorRecord
    )

    if ($ErrorRecord.Exception.GetType().FullName -eq "Microsoft.PowerShell.Commands.InvalidPasswordException") {
        return "Password was rejected by the local Windows password policy. Use at least $script:DeploymentMinimumPasswordLength characters, 3 character groups, and do not include the username."
    }
    return $ErrorRecord.Exception.Message
}

function Get-LocalizedUsersGroupName {
    $usersGroupFull = (New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-545")).Translate([System.Security.Principal.NTAccount]).Value
    return $usersGroupFull.Split('\')[-1]
}

function Add-UserToUsersGroup {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$UserName
    )

    $usersGroup = Get-LocalizedUsersGroupName
    try {
        $members = @(Get-LocalGroupMember -Group $usersGroup -ErrorAction Stop | Select-Object -ExpandProperty Name)
    }
    catch {
        throw "Could not read members of local group '$usersGroup': $($_.Exception.Message)"
    }

    if ($members -notcontains "$env:COMPUTERNAME\$UserName") {
        if ($PSCmdlet.ShouldProcess($UserName, "Add to $usersGroup group")) {
            Add-LocalGroupMember -Group $usersGroup -Member $UserName -ErrorAction Stop
            Write-Output "  Added to Users group."
        }
    }
}

$resolved = Resolve-DeploymentUserName -SystemPurpose $systemPurpose -SystemOwnership $systemOwnership `
    -DedicatedUserName $dedicatedUserName -PersonalUserName $personalUserName
$userName = $resolved.UserName
$enableAutoLogin = $resolved.EnableAutoLogin

if ($userName) {
    Test-LocalUserPassword -SecurePassword $userPassword -AccountName $userName
    $existingUser = Get-LocalUser -Name $userName -ErrorAction SilentlyContinue

    if (-not $existingUser) {
        Write-Output "Creating local user: $userName"
        try {
            Invoke-WithTranscriptSuspended -ScriptBlock {
                New-LocalUser -Name $userName -Password $userPassword -FullName $userName -Description "User created by deployment script" -ErrorAction Stop
            }
            Add-UserToUsersGroup -UserName $userName
            Write-Output "  User created."
        }
        catch {
            throw "Failed to create user '$userName': $(ConvertTo-FriendlyPasswordError -ErrorRecord $_)"
        }
    }
    else {
        Write-Output "User '$userName' already exists; syncing password and group membership."
        try {
            Invoke-WithTranscriptSuspended -ScriptBlock {
                Set-LocalUser -Name $userName -Password $userPassword -ErrorAction Stop
            }
            Write-Output "  Password synced with deployment input."
        }
        catch {
            throw "Failed to sync password for '$userName': $(ConvertTo-FriendlyPasswordError -ErrorRecord $_)"
        }

        try {
            Add-UserToUsersGroup -UserName $userName
        }
        catch {
            throw "Failed to add '$userName' to Users group: $($_.Exception.Message)"
        }
    }
}

$regPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
if ($userName -and $enableAutoLogin) {
    Write-Output "Configuring auto-login for: $userName"
    try {
        if (-not $userPassword) {
            throw "A password is required for auto-login."
        }

        Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $userName -Force -ErrorAction Stop
        Invoke-WithTranscriptSuspended -ScriptBlock {
            $plainPassword = ConvertFrom-SecureStringToPlainText -SecureString $userPassword
            Set-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $plainPassword -Force -ErrorAction Stop
        }
        Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value 1 -Force -ErrorAction Stop
        Write-Output "  Auto-login configured."
    }
    catch {
        throw "Failed to configure auto-login for '$userName': $($_.Exception.Message)"
    }
}

Write-Output "Setting password policy (max age unlimited)..."
Invoke-NativeCommand -FilePath "net.exe" `
    -Arguments @("accounts", "/maxpwage:unlimited") `
    -FailureMessage "Failed to set password policy" | Out-Null

Write-Output "User settings configured."

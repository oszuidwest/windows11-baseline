# Define script parameters
param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
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
        return "Password was rejected by the local Windows password policy. Use at least 8 characters, 3 character groups, and do not include the username."
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
    $members = Get-LocalGroupMember -Group $usersGroup -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name

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

# Create or sync the local user account
if ($userName) {
    Test-LocalUserPassword -Candidate $userPassword -AccountName $userName
    $securePassword = ConvertTo-SecureString -String $userPassword -AsPlainText -Force
    $existingUser = Get-LocalUser -Name $userName -ErrorAction SilentlyContinue

    if (-not $existingUser) {
        Write-Output "Creating local user: $userName"
        try {
            New-LocalUser -Name $userName -Password $securePassword -FullName $userName -Description "User created by deployment script" -ErrorAction Stop
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
            Set-LocalUser -Name $userName -Password $securePassword -ErrorAction Stop
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

# Set registry values for auto-login if enabled
$regPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
if ($userName -and $enableAutoLogin) {
    Write-Output "Configuring auto-login for: $userName"
    try {
        if ([string]::IsNullOrWhiteSpace($userPassword)) {
            throw "A password is required for auto-login."
        }

        Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $userName -Force -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $userPassword -Force -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value 1 -Force -ErrorAction Stop
        Write-Output "  Auto-login configured."
    }
    catch {
        throw "Failed to configure auto-login for '$userName': $($_.Exception.Message)"
    }
}

# Set maximum password age to unlimited
Write-Output "Setting password policy (max age unlimited)..."
try {
    Invoke-NativeCommand -FilePath "net.exe" `
        -Arguments @("accounts", "/maxpwage:unlimited") `
        -FailureMessage "Failed to set password policy" | Out-Null
}
catch {
    Write-Warning $_.Exception.Message
}

Write-Output "User settings configured."

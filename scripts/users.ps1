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

function Test-LocalUserPassword {
    param (
        [Parameter(Mandatory)]
        [string]$Candidate,

        [Parameter(Mandatory)]
        [string]$AccountName
    )

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        throw "A password is required when creating '$AccountName'."
    }

    if ($Candidate.Length -lt 8) {
        throw "The password for '$AccountName' must be at least 8 characters."
    }

    $characterClasses = 0
    if ($Candidate -cmatch "[A-Z]") { $characterClasses++ }
    if ($Candidate -cmatch "[a-z]") { $characterClasses++ }
    if ($Candidate -match "\d") { $characterClasses++ }
    if ($Candidate -match "[^a-zA-Z\d]") { $characterClasses++ }

    if ($characterClasses -lt 3) {
        throw "The password for '$AccountName' must contain characters from at least 3 of these groups: uppercase, lowercase, numbers, symbols."
    }

    $userNameParts = @($AccountName -split "[\s._-]+" | Where-Object { $_.Length -ge 3 })
    foreach ($userNamePart in $userNameParts) {
        if ($Candidate.IndexOf($userNamePart, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            throw "The password for '$AccountName' must not contain username part '$userNamePart'."
        }
    }
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

# Determine username based on ownership and purpose
if ($systemOwnership -eq "dedicated" -and $dedicatedUserName) {
    # Dedicated system with custom user
    $userName = $dedicatedUserName
    $enableAutoLogin = $true
}
elseif ($systemOwnership -eq "personal" -and $personalUserName) {
    # Personal system with custom user (no auto-login)
    $userName = $personalUserName
    $enableAutoLogin = $false
}
elseif ($systemOwnership -eq "shared") {
    # Shared system with purpose-based user
    $userName = switch ($systemPurpose) {
        'editorial' { "Redactie Gebruiker" }
        'tv' { "Studio Gebruiker" }
        'radio' { "Studio Gebruiker" }
        default { "" }
    }
    $enableAutoLogin = ($systemPurpose -ne "plain")
}
else {
    $userName = ""
    $enableAutoLogin = $false
}

# Add user if userName is specified
if ($userName) {
    if (-not (Get-LocalUser -Name $userName -ErrorAction SilentlyContinue)) {
        Write-Output "Creating local user: $userName"
        try {
            Test-LocalUserPassword -Candidate $userPassword -AccountName $userName
            $securePassword = ConvertTo-SecureString -String $userPassword -AsPlainText -Force
            New-LocalUser -Name $userName -Password $securePassword -FullName $userName -Description "User created by deployment script" -ErrorAction Stop
            Add-UserToUsersGroup -UserName $userName
            Write-Output "  User created."
        }
        catch {
            $errorMessage = $_.Exception.Message
            if ($_.Exception.GetType().FullName -eq "Microsoft.PowerShell.Commands.InvalidPasswordException") {
                $errorMessage = "Password was rejected by the local Windows password policy. Use at least 8 characters, 3 character groups, and do not include the username."
            }
            throw "Failed to create user '$userName': $errorMessage"
        }
    }
    else {
        Write-Output "User '$userName' already exists."
        # Ensure user is in Users group (may be missing if created before fix)
        try {
            Add-UserToUsersGroup -UserName $userName
        }
        catch {
            Write-Warning "Failed to add to Users group: $_"
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

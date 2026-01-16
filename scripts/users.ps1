# Define script parameters
param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName,
    [string]$dwAgentCode,
    [string]$dedicatedUserName,
    [string]$personalUserName
)

Write-Output "Configuring user settings..."

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
            $securePassword = ConvertTo-SecureString -String $userPassword -AsPlainText -Force
            New-LocalUser -Name $userName -Password $securePassword -FullName $userName -Description "User created by deployment script" -ErrorAction Stop
            Write-Output "  User created successfully."
        }
        catch {
            Write-Error "Failed to create user: $_"
        }
    }
    else {
        Write-Output "User '$userName' already exists."
    }
}

# Set registry values for auto-login if enabled
$regPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
if ($userName -and $enableAutoLogin) {
    Write-Output "Configuring auto-login for: $userName"
    try {
        Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $userName -Force -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $userPassword -Force -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value 1 -Force -ErrorAction Stop
        Write-Output "  Auto-login configured."
    }
    catch {
        Write-Error "Failed to configure auto-login: $_"
    }
}

# Set maximum password age to unlimited
Write-Output "Setting password policy (max age unlimited)..."
$netResult = net accounts /maxpwage:unlimited 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to set password policy: $netResult"
}

Write-Output "User settings configured."
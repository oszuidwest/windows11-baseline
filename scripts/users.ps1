# Define script parameters
param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName,
    [string]$dwAgentCode
)

Write-Output "Configuring user settings..."

# Map purpose to username
$userName = switch ($systemPurpose) {
    'editorial' { "Redactie Gebruiker" }
    'tv' { "Studio Gebruiker" }
    'radio' { "Studio Gebruiker" }
    default { "" }
}

# Add user if ownership is shared and userName is specified
if ($systemOwnership -eq "shared" -and $userName -ne "") {
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

# Set registry values if userName is specified
$regPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
if ($userName -ne "") {
    Write-Output "Configuring auto-login for: $userName"
    try {
        Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $userName -Force -ErrorAction Stop

        if ($systemPurpose -ne "plain") {
            Set-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $userPassword -Force -ErrorAction Stop
            Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value 1 -Force -ErrorAction Stop
        }
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
# Define script parameters
param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName
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
        $securePassword = ConvertTo-SecureString -String $userPassword -AsPlainText -Force
        New-LocalUser -Name $userName -Password $securePassword -FullName $userName -Description "User created by deployment script"
    }
}

# Set registry values if userName is specified
$regPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
if ($userName -ne "") {
    Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $userName -Force
    
    if ($systemPurpose -ne "plain") {
        Set-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $userPassword -Force
        Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value 1 -Force
    }
}

# Set maximum password age to unlimited
net accounts /maxpwage:unlimited | Out-Null

Write-Output "User settings configured."
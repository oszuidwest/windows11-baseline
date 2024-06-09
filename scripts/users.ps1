# Define script parameters
param (
    [string]$purpose,
    [string]$ownership,
    [string]$password,
    [string]$computername, # pragma: allow(PSReviewUnusedParameter)
    [string]$workgroup    # pragma: allow(PSReviewUnusedParameter)
)

# Map purpose to username
$userName = switch ($purpose) {
    'editorial' { "Redactie Gebruiker" }
    'tv' { "Studio Gebruiker" }
    'radio' { "Studio Gebruiker" }
    default { "" }
}

# Add user if ownership is shared and userName is specified
if ($ownership -eq "shared" -and $userName -ne "") {
    if (-not (Get-LocalUser -Name $userName -ErrorAction SilentlyContinue)) {
        New-LocalUser -Name $userName -Password (ConvertTo-SecureString $password -AsPlainText -Force) -FullName $userName -Description "User created by deployment script"
    }
}

# Set registry values if userName is specified
$regPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
if ($userName -ne "") {
    Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $userName -Force
    if ($purpose -ne "plain") {
        Set-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $password -Force
        Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value 1 -Force
    }
}

# Set maximum password age to unlimited
Start-Process -FilePath "cmd.exe" -ArgumentList "/c net accounts /maxpwage:unlimited" -NoNewWindow -Wait -Verb RunAs

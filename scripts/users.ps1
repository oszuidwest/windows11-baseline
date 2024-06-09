# Define script parameters
param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [securestring]$userPassword,
    [string]$computerName,
    [string]$workgroupName
)

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
        New-LocalUser -Name $userName -Password $password -FullName $userName -Description "User created by deployment script"
    }
}

# Function to convert SecureString to plain text for registry purposes
function Convert-SecureStringToPlainText ($secureString) {
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
}

# Set registry values if userName is specified
$regPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
if ($userName -ne "") {
    Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $userName -Force
    
    if ($systemPurpose -ne "plain") {
        # Convert SecureString password to plain text for registry entry
        $plainTextPassword = Convert-SecureStringToPlainText $userPassword
        Set-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $plainTextPassword -Force
        Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value 1 -Force
    }
}

# Set maximum password age to unlimited
Start-Process -FilePath "cmd.exe" -ArgumentList "/c net accounts /maxpwage:unlimited" -NoNewWindow -Wait -Verb RunAs

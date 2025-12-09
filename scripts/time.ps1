param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName,
    [string]$dwAgentCode,
    [string]$dedicatedUserName
)

Write-Output "Configuring time settings..."

# Set timezone to Amsterdam
Write-Output "Setting timezone to W. Europe Standard Time (Amsterdam)..."
try {
    Set-TimeZone -Id "W. Europe Standard Time" -ErrorAction Stop
    Write-Output "  Timezone set."
}
catch {
    Write-Error "Failed to set timezone: $_"
}

# Set regional settings to Netherlands (nl-NL)
Write-Output "Setting regional format to Dutch (Netherlands)..."
try {
    Set-WinSystemLocale -SystemLocale "nl-NL" -ErrorAction Stop
    Set-WinUserLanguageList -LanguageList "nl-NL" -Force -ErrorAction Stop
    Set-Culture -CultureInfo "nl-NL" -ErrorAction Stop
    Set-WinHomeLocation -GeoId 176 -ErrorAction Stop
    Write-Output "  Regional settings configured."

    # Copy settings to new user profiles and welcome screen
    Write-Output "  Copying regional settings to default user profile..."
    Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true -ErrorAction Stop
    Write-Output "  Regional settings will apply to new users."
}
catch {
    Write-Error "Failed to set regional settings: $_"
}

# Ensure the Windows Time Service is running
Write-Output "Starting Windows Time Service..."
try {
    if ((Get-Service -Name w32time).Status -ne 'Running') {
        Start-Service -Name w32time -ErrorAction Stop
    }
    Set-Service -Name w32time -StartupType Automatic -ErrorAction Stop
    Write-Output "  Time service running."
}
catch {
    Write-Error "Failed to start time service: $_"
}

# Configure the Windows Time Service to use the specified NTP servers
Write-Output "Configuring NTP servers (nl.pool.ntp.org)..."
$ntpServers = "0.nl.pool.ntp.org,1.nl.pool.ntp.org,2.nl.pool.ntp.org,3.nl.pool.ntp.org"

$result = w32tm /config /manualpeerlist:$ntpServers /syncfromflags:manual /reliable:NO /update 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "NTP config failed: $result"
}

# Forcing a resynchronization
Write-Output "Syncing time..."
$result = w32tm /resync /rediscover 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Time sync failed: $result"
}
else {
    Write-Output "  Time synchronized."
}

Write-Output "Time settings configured."

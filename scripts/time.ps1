param()

. (Join-Path $PSScriptRoot "_common.ps1")

Write-Output "Configuring time settings..."

Write-Output "Setting timezone to W. Europe Standard Time (Amsterdam)..."
try {
    Set-TimeZone -Id "W. Europe Standard Time" -ErrorAction Stop
    Write-Output "  Timezone set."
}
catch {
    throw "Failed to set timezone: $($_.Exception.Message)"
}

Write-Output "Setting regional format to Dutch (Netherlands)..."
try {
    Set-WinSystemLocale -SystemLocale "nl-NL" -ErrorAction Stop
    Set-WinUserLanguageList -LanguageList "nl-NL" -Force -ErrorAction Stop
    Set-Culture -CultureInfo "nl-NL" -ErrorAction Stop
    Set-WinHomeLocation -GeoId 176 -ErrorAction Stop
    Write-Output "  Regional settings configured."

    Write-Output "  Copying regional settings to default user profile..."
    Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true -ErrorAction Stop
    Write-Output "  Regional settings will apply to new users."
}
catch {
    throw "Failed to set regional settings: $($_.Exception.Message)"
}

Write-Output "Starting Windows Time Service..."
try {
    if ((Get-Service -Name w32time).Status -ne 'Running') {
        Start-Service -Name w32time -ErrorAction Stop
    }
    Set-Service -Name w32time -StartupType Automatic -ErrorAction Stop
    Write-Output "  Time service running."
}
catch {
    throw "Failed to start time service: $($_.Exception.Message)"
}

Write-Output "Configuring NTP servers (nl.pool.ntp.org)..."
$ntpServers = "0.nl.pool.ntp.org,1.nl.pool.ntp.org,2.nl.pool.ntp.org,3.nl.pool.ntp.org"

try {
    Invoke-NativeCommand -FilePath "w32tm" `
        -Arguments @("/config", "/manualpeerlist:$ntpServers", "/syncfromflags:manual", "/reliable:NO", "/update") `
        -FailureMessage "NTP config failed" | Out-Null
}
catch {
    Write-Warning $_.Exception.Message
}

Write-Output "Syncing time..."
try {
    Invoke-NativeCommand -FilePath "w32tm" `
        -Arguments @("/resync", "/rediscover") `
        -FailureMessage "Time sync failed" | Out-Null
    Write-Output "  Time synchronized."
}
catch {
    Write-Warning $_.Exception.Message
}

Write-Output "Time settings configured."

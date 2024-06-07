# Ensure the Windows Time Service is running
if ((Get-Service -Name w32time).Status -ne 'Running') {
    Start-Service -Name w32time
}

# Configure the Windows Time Service to use the specified NTP servers
$ntpServers = "0.nl.pool.ntp.org,1.nl.pool.ntp.org,2.nl.pool.ntp.org,3.nl.pool.ntp.org"
$specialPollInterval = 3600 # Time in seconds (3600 seconds = 1 hour)

sudo w32tm /config /manualpeerlist:$ntpServers /syncfromflags:manual /reliable:NO /update
sudo w32tm /config /specialpollinterval:$specialPollInterval

# Apply the new configuration
sudo w32tm /config /update

# Forcing a resynchronization and rediscovering the time source
sudo w32tm /resync /rediscover

# Set the Windows Time Service to start automatically
sudo Set-Service -Name w32time -StartupType Automatic

# Confirm the time synchronization status
sudo w32tm /query /status

param (
    [string]$systemPurpose,
    [string]$systemOwnership,
    [string]$userPassword,
    [string]$computerName,
    [string]$workgroupName,
    [string]$dwAgentCode
)

Write-Output "Configuring power settings..."

# Set monitor timeout for AC and DC power
powercfg /change monitor-timeout-ac 30
powercfg /change monitor-timeout-dc 30

# Set disk timeout for AC and DC power (with modern flash storage, disk timeout isn't necessary, so we disable it)
powercfg /change disk-timeout-ac 0
powercfg /change disk-timeout-dc 0

# Set standby timeout for AC and DC power
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 60

# Set hibernate timeout for AC and DC power
powercfg /change hibernate-timeout-ac 0
powercfg /change hibernate-timeout-dc 0

# Turn off hibernation
powercfg /hibernate off

Write-Output "Power settings configured."
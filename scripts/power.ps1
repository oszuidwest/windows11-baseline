# Set monitor timeout for AC and DC power
powercfg.exe /change monitor-timeout-ac 30
powercfg.exe /change monitor-timeout-dc 30

# Set disk timeout for AC and DC power (with modern flash storage, disk timeout isn't necessary, so we disable it)
powercfg.exe /change disk-timeout-ac 0
powercfg.exe /change disk-timeout-dc 0

# Set standby timeout for AC and DC power
powercfg.exe /change standby-timeout-ac 0
powercfg.exe /change standby-timeout-dc 60

# Set hibernate timeout for AC and DC power
powercfg.exe /change hibernate-timeout-ac 0
powercfg.exe /change hibernate-timeout-dc 0

# Turn off hibernation
powercfg.exe /hibernate off

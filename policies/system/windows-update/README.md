# Windows Update Policies

Auto-downloads and installs updates daily at 3:00 AM. Users cannot pause updates.

## Policies

### `configure-auto-update.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `NoAutoUpdate` | 0 | Automatic Windows updates are enabled |
| `AUOptions` | 4 | Automatically download and schedule installation |
| `ScheduledInstallDay` | 0 | Updates install every day |
| `ScheduledInstallTime` | 3 | Updates install at 3:00 AM |
| `ScheduledInstallEveryWeek` | 1 | Updates install weekly on specified day |
| `AutomaticMaintenanceEnabled` | 1 | Updates install during maintenance window |
| `SetDisablePauseUXAccess` | 1 | Users cannot pause Windows Update |
| `NoAUShutdownOption` | 1 | Hides "Install Updates and Shut Down" option |
| `AlwaysAutoRebootAtScheduledTime` | 1 | Forces restart after update installation |
| `AlwaysAutoRebootAtScheduledTimeMinutes` | 15 | Device restarts 15 minutes after update |
| `AutoRestartNotificationSchedule` | 15 | Restart reminder shows 15 minutes before reboot |
| `UpdateNotificationLevel` | 1 | Disables notifications except restart warnings |

# Windows Update Policies

Auto-downloads and installs updates daily at 3:00 AM. Users cannot pause updates. Active hours (6:00-23:00) prevent restarts during work hours.

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
| `SetActiveHours` | 1 | Enable active hours (no restart during this period) |
| `ActiveHoursStart` | 6 | Active hours start at 6:00 AM |
| `ActiveHoursEnd` | 23 | Active hours end at 11:00 PM |
| `AutoRestartNotificationSchedule` | 15 | Restart reminder shows 15 minutes before reboot |
| `UpdateNotificationLevel` | 1 | Disables notifications except restart warnings |

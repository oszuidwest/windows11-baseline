# Windows Update Policies

These policies configure Windows Update behavior for automatic updates with minimal user disruption.

## Policies

### `configure-auto-update.txt`

Configures automatic updates to download and install automatically at 3:00 AM daily.

| Setting | Value | Description |
|---------|-------|-------------|
| `SetAutoRestartNotificationConfig` | 1 | Enable auto-restart notification configuration |
| `AutoRestartNotificationSchedule` | 15 | Show restart notification 15 minutes before restart |
| `SetUpdateNotificationLevel` | 1 | Enable update notification level setting |
| `UpdateNotificationLevel` | 1 | Show all notifications except restart warnings |
| `SetDisablePauseUXAccess` | 1 | Prevent users from pausing updates |
| `NoAUShutdownOption` | 1 | Remove "Update and Shut Down" option (forces restart) |
| `AlwaysAutoRebootAtScheduledTime` | 1 | Always restart at the scheduled time |
| `AlwaysAutoRebootAtScheduledTimeMinutes` | 15 | Wait 15 minutes before forced restart |
| `NoAutoUpdate` | 0 | Enable automatic updates |
| `AUOptions` | 4 | Auto download and schedule install |
| `AutomaticMaintenanceEnabled` | 1 | Enable automatic maintenance |
| `ScheduledInstallDay` | 0 | Install every day (0 = every day) |
| `ScheduledInstallTime` | 3 | Install at 3:00 AM |
| `ScheduledInstallEveryWeek` | 1 | Install updates every week |

The policy also removes week-specific scheduling settings:

| Setting | Action | Description |
|---------|--------|-------------|
| `ScheduledInstallFirstWeek` | DELETE | Remove first week only scheduling |
| `ScheduledInstallSecondWeek` | DELETE | Remove second week only scheduling |
| `ScheduledInstallThirdWeek` | DELETE | Remove third week only scheduling |
| `ScheduledInstallFourthWeek` | DELETE | Remove fourth week only scheduling |
| `AllowMUUpdateService` | DELETE | Remove Microsoft Update Service option |

## Schedule

- **Installation time**: Daily at 3:00 AM
- **Restart behavior**: Auto-restart 15 minutes after installation with notification
- **User control**: Users cannot pause updates

## Why

- Ensures systems stay up-to-date with security patches
- Schedules updates during off-hours (3 AM) to minimize disruption
- Prevents users from indefinitely postponing critical updates
- Maintains consistent update behavior across all workstations

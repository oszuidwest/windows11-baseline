# Privacy Policies

Minimizes data sent to Microsoft: telemetry, location, advertising ID, clipboard sync, activity history.

## Policies

### `disable-tracking.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `DisableLocation` | 1 | Turns off location services system-wide |
| `DisabledByGroupPolicy` | 1 | Prevents apps from using advertising ID |
| `DisableTailoredExperiencesWithDiagnosticData` | 1 | Stops Windows using diagnostic data for personalization |
| `AllowTelemetry` | 0 | Disables telemetry (Enterprise/Education only) |
| `PreventHandwritingDataSharing` | 1 | Blocks handwriting data sharing with Microsoft |
| `PreventHandwritingErrorReports` | 1 | Disables handwriting recognition error reporting |
| `AllowInputPersonalization` | 0 | Disables online speech recognition services |

### `disable-clipboard-history.txt`

Shared and dedicated systems only.

| Setting | Value | Effect |
|---------|-------|--------|
| `AllowClipboardHistory` | 0 | Prevents clipboard from storing multiple items |
| `AllowCrossDeviceClipboard` | 0 | Blocks clipboard sync across devices |

### `disable-activity-history.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `EnableActivityFeed` | 0 | Disables Timeline activity publishing and sync |
| `PublishUserActivities` | 0 | Prevents user activities from being published |
| `UploadUserActivities` | 0 | Blocks user activities from uploading to cloud |

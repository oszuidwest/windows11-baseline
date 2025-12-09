# Security Policies

Disables autorun (malware prevention) and hides shutdown button (forces restart for updates).

## Policies

### `disable-autorun.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `NoDriveTypeAutoRun` | 255 | Disables AutoRun/AutoPlay for all drive types |

### `hide-shutdown-button.txt`

Shared systems only. Ensures workstations are restarted (applying updates) rather than shut down.

| Setting | Value | Effect |
|---------|-------|--------|
| `HideShutDown` | 1 | Removes Shutdown option from Start and login screen |

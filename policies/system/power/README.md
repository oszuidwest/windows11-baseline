# Power Policies

Power menu restrictions for shared workstations.

## Policies

### `disable-shutdown.txt`

Hides the Shutdown option from the power menu, keeping only Restart available.

| Setting | Value | Description |
|---------|-------|-------------|
| `HideShutDown` | 1 | Hide Shutdown option from Start menu, login screen, and Ctrl+Alt+Del |

## Affected Locations

The Shutdown button is hidden from:
- Start menu power options
- Login/lock screen
- Ctrl+Alt+Del screen
- WinX menu (Win+X)

## What Remains Available

- Restart
- Sign out
- Sleep (if enabled)

## Why

- Prevents accidental shutdown of shared broadcast workstations
- Ensures computers remain available for the next user
- Restart is still available for updates and troubleshooting

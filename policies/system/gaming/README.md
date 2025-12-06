# Gaming Policies

Disables gaming-related features that are unnecessary for workstations.

## Policies

### `disable-game-bar.txt`

Disables Xbox Game Bar and Game DVR functionality.

| Setting | Value | Description |
|---------|-------|-------------|
| `AllowGameDVR` | 0 | Disable Game DVR/recording |
| `AppCaptureEnabled` | 0 | Disable app capture functionality |

## Why

- Prevents accidental Game Bar activation (Win+G shortcut)
- Suppresses "broken Game Bar" popups on Windows 11 LTSC (Game Bar not installed)
- Removes unnecessary gaming overlay in broadcast environment
- Prevents unintended screen recording

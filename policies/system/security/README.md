# Security Policies

Security restrictions applied system-wide.

## Policies

### `disable-autorun.txt`

Disables autorun for all drive types.

| Setting | Value | Description |
|---------|-------|-------------|
| `NoDriveTypeAutoRun` | 255 | Disable autorun for all drive types |

### NoDriveTypeAutoRun Values

Value 255 (0xFF) disables autorun for all drive types:
- Removable drives (USB)
- Fixed drives
- Network drives
- CD-ROM drives
- RAM disks

### `hide-shutdown-button.txt`

Hides the shutdown button from Start menu, only allowing restart.

| Setting | Value | Description |
|---------|-------|-------------|
| `HideShutDown` | 1 | Hide shutdown button from Start menu |

Only applied to **shared** systems to ensure workstations are restarted (applying updates) rather than shut down.

## Why

- Prevents malware from auto-executing when USB drives are inserted
- Blocks autorun.inf exploits
- Ensures shared workstations are restarted, not shut down
- Standard security hardening measure

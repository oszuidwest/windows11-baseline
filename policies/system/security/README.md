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

## Why

- Prevents malware from auto-executing when USB drives are inserted
- Blocks autorun.inf exploits
- Standard security hardening measure

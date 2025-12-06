# User Security Policies

Security restrictions applied to non-admin users on shared systems.

## Policies

### `disable-command-prompt.txt`

Disables Command Prompt access for non-admin users.

| Setting | Value | Description |
|---------|-------|-------------|
| `DisableCMD` | 2 | Disable Command Prompt but allow batch files |

### DisableCMD Values

- `1` = Disable Command Prompt and batch files
- `2` = Disable Command Prompt only, batch files still work (recommended)

Value 2 is used to prevent breaking installers and scripts that rely on batch files.

### `disable-registry-editor.txt`

Disables Registry Editor access for non-admin users.

| Setting | Value | Description |
|---------|-------|-------------|
| `DisableRegistryTools` | 1 | Disable regedit.exe |

## Why

- Prevents users from running potentially harmful commands
- Blocks access to system configuration tools
- Reduces attack surface on shared workstations
- Standard security hardening for kiosk-style deployments

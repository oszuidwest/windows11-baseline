# User Security Policies

Security restrictions applied to non-admin users on shared systems.

## Policies

### `disable-command-prompt.txt`

Disables Command Prompt access for non-admin users.

| Setting | Value | Description |
|---------|-------|-------------|
| `DisableCMD` | 2 | Disable Command Prompt but allow batch files |

Value 2 is used to prevent breaking installers and scripts that rely on batch files.

### `disable-registry-editor.txt`

Disables Registry Editor access for non-admin users.

| Setting | Value | Description |
|---------|-------|-------------|
| `DisableRegistryTools` | 1 | Disable regedit.exe |

### `disable-powershell.txt`

Disables PowerShell script execution for non-admin users.

| Setting | Value | Description |
|---------|-------|-------------|
| `EnableScripts` | 0 | Disable script execution |
| `ExecutionPolicy` | Restricted | Most restrictive policy |

### `disable-run-dialog.txt`

Disables the Run dialog (Win+R) for non-admin users.

| Setting | Value | Description |
|---------|-------|-------------|
| `NoRun` | 1 | Disable Run dialog |

### `disable-task-manager.txt`

Disables Task Manager access for non-admin users.

| Setting | Value | Description |
|---------|-------|-------------|
| `DisableTaskMgr` | 1 | Disable Task Manager |

### `disable-control-panel.txt`

Disables Control Panel and Settings app access for non-admin users.

| Setting | Value | Description |
|---------|-------|-------------|
| `NoControlPanel` | 1 | Disable Control Panel and Settings |

### `disable-network-settings.txt`

Disables network connection property changes for non-admin users.

| Setting | Value | Description |
|---------|-------|-------------|
| `NC_LanProperties` | 0 | Disable LAN properties access |
| `NC_LanChangeProperties` | 0 | Disable LAN component changes |
| `NC_LanConnect` | 0 | Disable new LAN connections |

## Why

- Prevents users from running potentially harmful commands
- Blocks access to system configuration tools
- Reduces attack surface on shared workstations
- Standard security hardening for kiosk-style deployments

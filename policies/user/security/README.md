# User Security Policies

Shared systems only. Blocks system tools for non-admin users.

## Policies

### `disable-command-prompt.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `DisableCMD` | 2 | Disables Command Prompt but allows batch files |

### `disable-registry-editor.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `DisableRegistryTools` | 1 | Blocks access to Registry Editor (regedit.exe) |

### `disable-powershell.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `EnableScripts` | 0 | Sets execution policy to Restricted |
| `ExecutionPolicy` | Restricted | PowerShell operates as interactive shell only |

### `disable-run-dialog.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `NoRun` | 1 | Removes Run command from Start menu and Task Manager |

### `disable-task-manager.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `DisableTaskMgr` | 1 | Prevents users from starting Task Manager |

### `disable-control-panel.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `NoControlPanel` | 1 | Blocks access to Control Panel and Settings |

### `disable-network-settings.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `NC_LanProperties` | 0 | Disables Properties menu for LAN connections |
| `NC_LanChangeProperties` | 0 | Disables Properties button for LAN components |
| `NC_LanConnect` | 0 | Disables Connect and Disconnect buttons for LAN |

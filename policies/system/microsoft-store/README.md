# Microsoft Store Policies

Policies to restrict Microsoft Store and app installation on shared systems.

## Policies

### `disable-store.txt`

Blocks app installation vectors on shared systems.

| Setting | Value | Description |
|---------|-------|-------------|
| `EnableMSAppInstallerProtocol` | 0 | Blocks `ms-appinstaller://` protocol (prevents web-based app installs) |
| `DisableWindowsConsumerFeatures` | 1 | Disables Windows consumer features (suggestions, tips, Store promotions) |

**Note:** On Windows 11 24H2, the traditional "Turn off the Store application" GPO is [no longer honored](https://learn.microsoft.com/en-us/answers/questions/5563743/windows-11-24h2-cannot-block-microsoft-store-ignor). This baseline uses AppLocker (dynamically generated policy) to block the Store app, Copilot, and `StoreInstaller.exe` from `get.microsoft.com`.

## Why

- Prevents users from installing unauthorized applications
- Blocks web-based app installer protocol abuse
- Reduces attack surface on shared workstations
- Works in conjunction with AppLocker for complete Store blocking

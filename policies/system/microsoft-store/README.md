# Microsoft Store Policies

Blocks app installation vectors on shared systems. Works with AppLocker for complete Store blocking.

## Policies

### `disable-store.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `EnableMSAppInstallerProtocol` | 0 | Blocks installation via ms-appinstaller:// protocol |
| `DisableWindowsConsumerFeatures` | 1 | Blocks automatic app suggestions and promotional installs |

On Windows 11 24H2, the "Turn off the Store application" GPO is [no longer honored](https://learn.microsoft.com/en-us/answers/questions/5563743/windows-11-24h2-cannot-block-microsoft-store-ignor). This baseline uses AppLocker to block the Store app and `StoreInstaller.exe`.

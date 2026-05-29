# Bluetooth Policies

Disables Bluetooth functionality system-wide to reduce attack surface and prevent unauthorized wireless connections.

## Policies

### `disable-bluetooth.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `AllowBluetooth` | 0 | Disallows Bluetooth and prevents users from turning it on |
| `AllowBluetooth_ProviderSet` | 1 | Marks the PolicyManager Bluetooth setting as provider-enforced |
| `SettingsPageVisibility` | `hide:bluetooth` | Hides direct access to the Bluetooth Settings page |
| `DenyDeviceClasses` + list value `2` | `{e0cbf06c-cd8b-4647-bb8a-263b43f0f974}` | Blocks installation/usage of Bluetooth device class |
| `DenyDeviceClassesRetroactive` | 1 | Applies block to already installed Bluetooth devices |
| `Start` | 4 | Disables Bluetooth Support Service (bthserv) |

`AllowBluetooth` values: `0` = disallow Bluetooth, `2` = allow Bluetooth. Device class GUIDs use curly brackets `{}`. Service Start values: `0` = Boot, `1` = System, `2` = Automatic, `3` = Manual, `4` = Disabled.

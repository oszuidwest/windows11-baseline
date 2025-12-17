# Bluetooth Policies

## disable-bluetooth.txt

Disables Bluetooth functionality system-wide.

| Setting | Value |
|---------|-------|
| Registry Path | `HKLM\SOFTWARE\Policies\Microsoft\Windows\Connectivity` |
| Value Name | `AllowBluetooth` |
| Type | DWORD |
| Value | 0 |

### AllowBluetooth Values

| Value | Effect |
|-------|--------|
| 0 | Disable Bluetooth completely |
| 1 | Reserved (disable except for remote control) |
| 2 | Allow Bluetooth (default) |

### References

- [NinjaOne - Enable/Disable Bluetooth](https://www.ninjaone.com/blog/how-to-enable-or-disable-bluetooth-windows/)
- [Block Bluetooth with GPO](https://www.it-server-room.com/en/windows-security-block-bluetooth-connections-with-ad-gpo/)

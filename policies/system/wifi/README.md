# WiFi Policies

## disable-wifi.txt

Disables WiFi by setting the WLAN AutoConfig service (WlanSvc) startup type to Disabled.

| Setting | Value |
|---------|-------|
| Registry Path | `HKLM\SYSTEM\CurrentControlSet\Services\WlanSvc` |
| Value Name | `Start` |
| Type | DWORD |
| Value | 4 |

### Service Start Values

| Value | Startup Type |
|-------|--------------|
| 0 | Boot |
| 1 | System |
| 2 | Automatic |
| 3 | Manual |
| 4 | Disabled |

### Notes

- This completely disables WiFi functionality
- All WLAN adapters become inaccessible from Windows networking UI
- Applied to shared and dedicated systems only (personal systems retain WiFi)

### References

- [Disable WiFi Group Policy](https://bondy.tech/disable-wifi-group-policy/)
- [Microsoft Q&A - Disable Wireless LAN using GPO](https://learn.microsoft.com/en-us/answers/questions/1617241/can-i-disable-wireless-lan-using-group-policy)

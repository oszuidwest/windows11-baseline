# WiFi Policies

Disables WiFi functionality on shared and dedicated systems. Personal systems retain WiFi capability.

## Policies

### `disable-wifi.txt`

Shared and dedicated systems only.

| Setting | Value | Effect |
|---------|-------|--------|
| `Start` | 4 | Disables WLAN AutoConfig service (WlanSvc) |

Service Start values: `0` = Boot, `1` = System, `2` = Automatic, `3` = Manual, `4` = Disabled.

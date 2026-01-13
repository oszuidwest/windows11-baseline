# Bluetooth Policies

Disables Bluetooth functionality system-wide to reduce attack surface and prevent unauthorized wireless connections.

## Policies

### `disable-bluetooth.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `Start` | 4 | Disables Bluetooth Support Service (bthserv) |

Service Start values: `0` = Boot, `1` = System, `2` = Automatic, `3` = Manual, `4` = Disabled.

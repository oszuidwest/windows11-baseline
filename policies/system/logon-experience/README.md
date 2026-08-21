# Logon Experience Policies

Speeds up first logon and simplifies the login screen for single-purpose machines.

## Policies

### `disable-logon-animations.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `EnableFirstLogonAnimation` | 0 | Disables animated "Hi" screen at first user logon |
| `HideFastUserSwitching` | 1 | Hides Switch User option from sign-in and Start menu |

### `disable-inactivity-lock.inf`

Dedicated systems only. Overrides the Microsoft Windows 11 security baseline's 15-minute inactivity limit.

| Setting | Value | Effect |
|---------|-------|--------|
| `InactivityTimeoutSecs` | 0 | Prevents Windows from automatically locking an inactive session |

# Logon Experience Policies

Speeds up first logon and simplifies the login screen for single-purpose machines.

## Policies

### `disable-logon-animations.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `EnableFirstLogonAnimation` | 0 | Disables animated "Hi" screen at first user logon |
| `HideFastUserSwitching` | 1 | Hides Switch User option from sign-in and Start menu |

### `disable-inactivity-lock.inf`

Dedicated systems of every purpose, plus shared radio and TV production systems. Overrides the Microsoft Windows 11 security baseline's 15-minute inactivity limit while leaving shared editorial and plain systems unchanged.

| Setting | Value | Effect |
|---------|-------|--------|
| `InactivityTimeoutSecs` | 0 | Prevents Windows from automatically locking an inactive session |

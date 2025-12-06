# Logon Experience Policies

These policies streamline the Windows logon experience.

## Policies

### `disable-logon-animations.txt`

Disables first logon animations and hides fast user switching.

| Setting | Value | Description |
|---------|-------|-------------|
| `EnableFirstLogonAnimation` | 0 | Disables the "Hi, we're getting things ready for you" animation on first logon |
| `HideFastUserSwitching` | 1 | Hides the Switch User option from the logon screen and Start menu |

## Why

- Speeds up first logon for new user profiles
- Simplifies login experience on shared/dedicated workstations
- Prevents confusion with multiple user accounts on single-purpose machines

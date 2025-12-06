# Microsoft Account Policies

These policies disable Microsoft Account and Work/School account connections.

## Policies

### `disable-microsoft-account.txt`

Prevents users from connecting Microsoft accounts and Work/School accounts.

| Setting | Value | Description |
|---------|-------|-------------|
| `DisableUserAuth` | 1 | Disable Microsoft Account sign-in |
| `BlockAADWorkplaceJoin` | 1 | Block Azure AD / Work or School account connection |
| `NoConnectedUser` | 3 | Disallow Microsoft accounts completely (can't add or sign in) |

### NoConnectedUser Values

- `0` = Allow Microsoft accounts
- `1` = Can't add Microsoft accounts (existing still work)
- `3` = Can't add or sign in with Microsoft accounts

## Why

- Forces use of local accounts only on shared workstations
- Blocks "Toegang tot werk of school" (Access work or school) in Settings
- Prevents cloud sync of settings and data
- Ensures consistent local-only user management

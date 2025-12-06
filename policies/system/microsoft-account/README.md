# Microsoft Account Policies

These policies disable Microsoft Account authentication.

## Policies

### `disable-microsoft-account.txt`

Prevents users from signing in with Microsoft accounts.

| Setting | Value | Description |
|---------|-------|-------------|
| `EnterpriseDeviceAuthOnly` | 0 | Allow device authentication only |
| `DisableUserAuth` | 1 | Disable user authentication via Microsoft Account |

## Why

- Forces use of local accounts only
- Prevents cloud sync of settings and data
- Keeps workstations independent of Microsoft cloud services
- Ensures consistent local-only user management

# Microsoft Account Policies

Forces local-only accounts by blocking Microsoft and Work/School account connections.

## Policies

### `disable-microsoft-account.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `DisableUserAuth` | 1 | Blocks apps from authenticating with Microsoft accounts |
| `BlockAADWorkplaceJoin` | 1 | Prevents Azure AD workplace join device registration |
| `NoConnectedUser` | 3 | Blocks adding and logging in with Microsoft accounts |

NoConnectedUser values: `0` = allow, `1` = can't add new, `3` = fully blocked.

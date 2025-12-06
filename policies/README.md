# Windows 11 Group Policies

This directory contains Local Group Policy settings in LGPO text format for configuring Windows 11 workstations.

## Structure

```
policies/
├── config.json                  # Policy-to-scope mapping
├── config.schema.json           # JSON schema for validation
├── system/                      # Computer-level policies (HKLM)
│   ├── bloatware/
│   ├── logon-experience/
│   ├── microsoft-account/
│   ├── onedrive/
│   ├── oobe/
│   ├── privacy/
│   ├── windows-feeds/
│   └── windows-update/
└── user/                        # User-level policies (HKCU, non-admin only)
    └── wallpaper/
```

## Conditional Policy Application

Policies can be applied conditionally based on **system purpose** and **ownership type**. The `config.json` file maps each policy file to its applicable scopes.

### Configuration Format

```json
{
  "policies": {
    "system/onedrive/disable-onedrive-sync.txt": {
      "purposes": ["all"],
      "ownership": ["shared", "dedicated"],
      "description": "Disable OneDrive file synchronization"
    }
  }
}
```

### Available Scopes

| Purpose | Description |
|---------|-------------|
| `all` | Apply to all system purposes |
| `radio` | Radio production workstations |
| `tv` | TV production workstations |
| `editorial` | Editorial/office workstations |
| `plain` | Basic workstations without specific purpose |

| Ownership | Description |
|-----------|-------------|
| `all` | Apply to all ownership types |
| `shared` | Shared workstations (multiple users, auto-login) |
| `personal` | Personal workstations (single user) |
| `dedicated` | Dedicated workstations (specific function) |

## Policy Matrix

| Policy | Description | Shared | Personal | Dedicated |
|--------|-------------|:------:|:--------:|:---------:|
| Disable web search | Remove Bing from Start menu | x | x | x |
| Disable logon animations | Skip first-run animations | x | x | x |
| Disable Microsoft Account | Block MS/Work/School accounts | x | | |
| Disable OneDrive sync | Prevent cloud sync | x | | |
| Disable OOBE privacy | Skip privacy wizard | x | x | x |
| Disable tracking | Telemetry, location, ads | x | x | x |
| Disable Widgets | Remove Widgets panel | x | x | x |
| Windows Update | Auto-update daily at 3 AM | x | x | x |
| Set wallpaper | Lock desktop wallpaper | x | | |

## File Format

Policy files use LGPO.exe text format:

```
Computer|User
Registry\Path
ValueName
TYPE:Value
```

Types:
- `DWORD:n` - 32-bit integer
- `SZ:string` - String value
- `EXSZ:string` - Expandable string
- `DELETE` - Remove the value

## Adding New Policies

1. Create a new directory under `system/` or `user/`
2. Add policy `.txt` file(s) in LGPO format
3. Add a `README.md` documenting each policy setting
4. Register the policy in `config.json` with appropriate scopes

## References

- [LGPO Documentation](https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/security-compliance-toolkit-10#lgpo-exe)
- [Group Policy Settings Reference](https://admx.help/)

# Windows 11 Group Policies

This directory contains Local Group Policy settings in LGPO text format for configuring Windows 11 workstations.

## Structure

```
policies/
├── config.json                  # Policy-to-scope mapping
├── config.schema.json           # JSON schema for validation
├── system/                      # Computer-level policies (HKLM)
│   ├── bloatware/               # Game Bar, Spotlight, Widgets, Web Search
│   ├── logon-experience/        # First-run animations
│   ├── microsoft-account/       # Block MS Account auth
│   ├── microsoft-store/         # Block Store + app installer
│   ├── onedrive/                # Disable sync
│   ├── oobe/                    # Skip privacy wizard
│   ├── privacy/                 # Tracking, clipboard, activity history
│   ├── security/                # Autorun, shutdown button
│   └── windows-update/          # Auto-update configuration
└── user/                        # User-level policies (HKCU, non-admin only)
    ├── browser/                 # Edge: profile, privacy, autofill, UI, devtools, extensions
    ├── personalization/         # Wallpaper settings
    └── security/                # CMD, Registry, PowerShell, Run, Task Manager, Control Panel, Network
```

## Conditional Policy Application

Policies can be applied conditionally based on **system purpose** and **ownership type**. The `config.json` file maps each policy file to its applicable scopes.

### Configuration Format

```json
{
  "policies": {
    "system/onedrive/disable-onedrive-sync.txt": {
      "purposes": ["all"],
      "ownership": ["shared"],
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

| Scope | Category | Policy | Description | Shared | Personal | Dedicated |
|:-----:|----------|--------|-------------|:------:|:--------:|:---------:|
| system | bloatware | Disable web search | Remove Bing from Start menu | x | x | x |
| system | bloatware | Disable Spotlight | Remove tips and suggestions | x | x | x |
| system | bloatware | Disable Widgets | Remove Widgets panel | x | x | x |
| system | bloatware | Disable Game Bar | Suppress Game Bar popups | x | x | x |
| system | logon-experience | Disable logon animations | Skip first-run animations | x | x | x |
| system | microsoft-account | Disable Microsoft Account | Block MS/Work/School accounts | x | | |
| system | microsoft-store | Disable Store | Block Store, app installer, auto-downloads | x | | |
| system | onedrive | Disable OneDrive sync | Prevent cloud sync | x | | |
| system | oobe | Skip privacy wizard | Skip OOBE privacy wizard | x | x | x |
| system | privacy | Disable tracking | Telemetry, location, ads | x | x | x |
| system | privacy | Disable clipboard history | No clipboard history/cross-device | x | | |
| system | privacy | Disable activity history | No Timeline/activity uploads | x | x | x |
| system | security | Disable autorun | Block USB/CD autorun | x | x | x |
| system | security | Hide shutdown button | Only allow restart | x | | |
| system | windows-update | Configure auto-update | Daily at 3 AM | x | x | x |
| user | browser | Edge profile | Ephemeral profiles, no history/sync | x | | |
| user | browser | Edge privacy | Tracking prevention, no telemetry | x | x | x |
| user | browser | Edge autofill | No passwords, creditcards, import | x | | |
| user | browser | Edge UI | No Copilot, rewards, shopping, games | x | x | x |
| user | browser | Edge developer tools | Disable F12 developer tools | x | | |
| user | browser | Edge extensions | Block all extension installs | x | | |
| user | personalization | Branded wallpaper | ZuidWest wallpaper (locked) | x | | |
| user | personalization | Black wallpaper | Solid black background (locked) | | | x |
| user | security | Disable Command Prompt | Block cmd.exe access | x | | |
| user | security | Disable Registry Editor | Block regedit.exe access | x | | |
| user | security | Disable PowerShell | Block PowerShell access | x | | |
| user | security | Disable Run dialog | Block Win+R access | x | | |
| user | security | Disable Task Manager | Block Task Manager access | x | | |
| user | security | Disable Control Panel | Block Control Panel and Settings | x | | |
| user | security | Disable network settings | Block network property changes | x | | |

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

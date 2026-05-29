# Windows 11 Group Policies

This directory contains Local Group Policy settings in LGPO text format for configuring Windows 11 workstations.

## Structure

```
policies/
├── config.json                  # Policy-to-scope mapping
├── config.schema.json           # JSON schema for validation
├── applocker/                   # AppLocker policy templates (shared.xml, dedicated.xml)
├── system/                      # Computer-level policies (HKLM)
│   ├── bloatware/               # Game Bar, Spotlight, Widgets, Web Search
│   ├── bitlocker/               # BitLocker-related hardening safe for removable media workflows
│   ├── logon-experience/        # First-run animations
│   ├── microsoft-account/       # Block MS Account auth
│   ├── microsoft-store/         # Block Store + app installer
│   ├── onedrive/                # Disable sync
│   ├── oobe/                    # Skip privacy wizard
│   ├── privacy/                 # Tracking, clipboard, activity history
│   ├── security/                # Autorun, shutdown, NTLM, Defender
│   └── windows-update/          # Auto-update configuration
└── user/                        # User-level policies (HKCU, non-admin only)
    ├── browser/                 # Edge/Chrome browser policies
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

> **Note:** all policies in `config.json` currently use `purposes: ["all"]`. The purpose dimension is kept in the schema and the apply pipeline as a reserved future hook so that purpose-specific policies can be added without restructuring `config.json`. `scripts/ci/generate-policy-matrix.sh` enforces this assumption: it fails fast if any policy adopts a purpose-specific scope so the matrix cannot silently misrepresent it.

## Policy Matrix

The table below is generated from `config.json` by `scripts/ci/generate-policy-matrix.sh`. Do not edit by hand - run `./scripts/ci/generate-policy-matrix.sh write` after changing `config.json` (CI enforces this).

<!-- BEGIN_POLICY_MATRIX -->
| Scope | Category | Policy | Description | Shared | Personal | Dedicated |
|:-----:|----------|--------|-------------|:------:|:--------:|:---------:|
| system | bitlocker | Removable Media Safe | Apply BitLocker-related hardening without blocking writes to SD cards or USB media | x | x | x |
| system | bloatware | Disable Game Bar | Disable Game Bar popups and DVR (not installed on LTSC) | x | x | x |
| system | bloatware | Disable Spotlight | Disable Windows Spotlight tips and suggestions | x | x | x |
| system | bloatware | Disable Web In Search | Disable web search and suggestions in Start menu | x | x | x |
| system | bloatware | Disable Widgets | Disable Windows 11 Widgets panel | x | x | x |
| system | bluetooth | Disable Bluetooth | Disable Bluetooth by blocking Bluetooth device class and disabling bthserv | x | x | x |
| system | logon-experience | Disable Logon Animations | Disable first logon animation and fast user switching | x | x | x |
| system | microsoft-account | Disable Microsoft Account | Disable Microsoft Account authentication | x |   |   |
| system | microsoft-store | Disable Store | Block Store access, app installs, and prevent non-admin package installation | x |   |   |
| system | onedrive | Disable OneDrive Sync | Disable OneDrive file synchronization | x |   |   |
| system | oobe | Skip Privacy Wizard | Skip privacy wizard during Windows setup | x | x | x |
| system | privacy | Disable Activity History | Disable Windows Activity History and Timeline | x | x | x |
| system | privacy | Disable Clipboard History | Disable clipboard history and cross-device clipboard | x |   | x |
| system | privacy | Disable Recall | Disable Windows Recall AI screenshot feature | x |   | x |
| system | privacy | Disable Tracking | Disable telemetry, location, advertising ID and tracking | x | x | x |
| system | security | Defender Network Protection | Enable Defender Network Protection to block malicious domains | x | x | x |
| system | security | Defender PUA Protection | Enable Defender PUA (Potentially Unwanted Application) Protection | x | x | x |
| system | security | Disable Autorun | Disable autorun for USB, CD and other drives | x | x | x |
| system | security | Hide Shutdown Button | Hide shutdown button, only allow restart | x |   |   |
| system | security | NTLM Hardening | Force NTLMv2 only authentication (LmCompatibilityLevel 5) | x | x | x |
| system | security | SmartScreen | Enable Windows SmartScreen for apps and files | x | x | x |
| system | wifi | Disable WiFi | Disable WiFi by disabling WLAN AutoConfig service | x |   | x |
| system | windows-update | Configure Auto Update | Configure automatic updates daily at 3:00 AM | x | x | x |
| system | windows-update | Disable Auto Reboot | Prevent automatic reboot after updates (dedicated systems have auto-login) |   |   | x |
| user | browser | Chrome Autofill | Disable Chrome password manager, autofill, passkeys, payments, and imports | x |   |   |
| user | browser | Chrome Developer Tools | Disable Chrome Developer Tools (F12) | x |   |   |
| user | browser | Chrome Disable Sign In | Disable Chrome sign-in on shared and dedicated systems | x |   | x |
| user | browser | Chrome Extensions | Block all Chrome extension installations | x | x | x |
| user | browser | Chrome Google Accounts | Allow Google services only for ZuidWest account domains in Chrome | x | x | x |
| user | browser | Chrome Privacy | Chrome privacy, safe browsing, and telemetry defaults | x | x | x |
| user | browser | Chrome Profile | Chrome ephemeral profiles, no history, no sync | x |   |   |
| user | browser | Chrome Search | Set Google as the default Chrome search provider | x | x | x |
| user | browser | Chrome Sign In | Allow only ZuidWest Google accounts for Chrome sign-in on personal systems |   | x |   |
| user | browser | Chrome UI | Block Chrome notifications/popups, set ZuidWest homepage, and remove promotional UI | x | x | x |
| user | browser | Edge Autofill | Disable Edge autofill and data import | x |   |   |
| user | browser | Edge Developer Tools | Disable Edge Developer Tools (F12) | x |   |   |
| user | browser | Edge Disable Sign In | Disable Edge sign-in on shared and dedicated systems | x |   | x |
| user | browser | Edge Extensions | Block all Edge extension installations | x |   |   |
| user | browser | Edge Privacy | Edge tracking prevention and security | x | x | x |
| user | browser | Edge Profile | Edge ephemeral profiles, no history, no sync | x |   |   |
| user | browser | Edge Sign In | Allow only ZuidWest work/school accounts for Edge sign-in on personal systems |   | x |   |
| user | browser | Edge UI | Disable Edge bloatware UI elements and set homepage to zuidwestupdate.nl | x | x | x |
| user | personalization | Set Wallpaper Black | Set solid black wallpaper for dedicated systems |   |   | x |
| user | personalization | Set Wallpaper Branded | Set branded ZuidWest wallpaper for shared and personal systems | x | x |   |
| user | security | Disable Command Prompt | Disable Command Prompt for non-admin users | x |   |   |
| user | security | Disable Control Panel | Disable Control Panel and Settings app for non-admin users | x |   |   |
| user | security | Disable Network Settings | Disable network connection property changes for non-admin users | x |   |   |
| user | security | Disable PowerShell | Disable PowerShell for non-admin users | x |   |   |
| user | security | Disable Registry Editor | Disable Registry Editor for non-admin users | x |   |   |
| user | security | Disable Run Dialog | Disable Run dialog (Win+R) for non-admin users | x |   |   |
| user | security | Disable Task Manager | Disable Task Manager for non-admin users | x |   |   |
<!-- END_POLICY_MATRIX -->

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

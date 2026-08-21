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

The purpose and ownership scopes are combined: a policy applies only when both columns match the current system. The generated matrix lists purpose-specific policies explicitly.

## Policy Matrix

The table below is generated from `config.json` by `scripts/ci/generate-policy-matrix.sh`. Do not edit by hand - run `./scripts/ci/generate-policy-matrix.sh write` after changing `config.json` (CI enforces this).

<!-- BEGIN_POLICY_MATRIX -->
| Scope | Category | Policy | Description | Purposes | Shared | Personal | Dedicated |
|:-----:|----------|--------|-------------|----------|:------:|:--------:|:---------:|
| system | bitlocker | Removable Media Safe | Apply BitLocker-related hardening without blocking writes to SD cards or USB media | all | x | x | x |
| system | bloatware | Disable Game Bar | Disable Game Bar popups and DVR (not installed on LTSC) | all | x | x | x |
| system | bloatware | Disable Spotlight | Disable Windows Spotlight tips and suggestions | all | x | x | x |
| system | bloatware | Disable Web In Search | Disable web search and suggestions in Start menu | all | x | x | x |
| system | bloatware | Disable Widgets | Disable Windows 11 Widgets panel | all | x | x | x |
| system | bluetooth | Disable Bluetooth | Disable Bluetooth, hide its Settings page, block device class, and disable bthserv | all | x | x | x |
| system | logon-experience | Disable Inactivity Lock | Disable automatic workstation locking after inactivity | all |   |   | x |
| system | logon-experience | Disable Inactivity Lock Production Shared | Disable automatic workstation locking on shared radio and TV production systems | radio, tv | x |   |   |
| system | logon-experience | Disable Logon Animations | Disable first logon animation and fast user switching | all | x | x | x |
| system | microsoft-account | Disable Microsoft Account | Disable Microsoft Account authentication | all | x |   |   |
| system | microsoft-store | Disable Store | Block Store access, app installs, and prevent non-admin package installation | all | x |   |   |
| system | onedrive | Disable OneDrive Sync | Disable OneDrive file synchronization | all | x |   |   |
| system | oobe | Skip Privacy Wizard | Skip privacy wizard during Windows setup | all | x | x | x |
| system | privacy | Disable Activity History | Disable Windows Activity History and Timeline | all | x | x | x |
| system | privacy | Disable Clipboard History | Disable clipboard history and cross-device clipboard | all | x |   | x |
| system | privacy | Disable Recall | Disable Windows Recall AI screenshot feature | all | x |   | x |
| system | privacy | Disable Tracking | Disable telemetry, location, advertising ID and tracking | all | x | x | x |
| system | security | Defender Network Protection | Enable Defender Network Protection to block malicious domains | all | x | x | x |
| system | security | Defender PUA Protection | Enable Defender PUA (Potentially Unwanted Application) Protection | all | x | x | x |
| system | security | Disable Autorun | Disable autorun for USB, CD and other drives | all | x | x | x |
| system | security | Hide Shutdown Button | Hide shutdown button, only allow restart | all | x |   |   |
| system | security | NTLM Hardening | Force NTLMv2 only authentication (LmCompatibilityLevel 5) | all | x | x | x |
| system | security | SmartScreen | Enable Windows SmartScreen for apps and files | all | x | x | x |
| system | wifi | Disable WiFi | Disable WiFi by disabling WLAN AutoConfig service | all | x |   | x |
| system | windows-update | Configure Auto Update | Configure automatic updates daily at 3:00 AM | all | x | x | x |
| system | windows-update | Disable Auto Reboot | Prevent automatic reboot after updates (dedicated systems have auto-login) | all |   |   | x |
| user | browser | Chrome Autofill | Disable Chrome password manager, autofill, passkeys, payments, and imports | all | x |   |   |
| user | browser | Chrome Developer Tools | Disable Chrome Developer Tools (F12) | all | x |   |   |
| user | browser | Chrome Disable Sign In | Disable Chrome sign-in on shared and dedicated systems | all | x |   | x |
| user | browser | Chrome Extensions | Block all Chrome extension installations | all | x | x | x |
| user | browser | Chrome Google Accounts | Temporarily allow all Google account domains in Chrome | all | x | x | x |
| user | browser | Chrome Privacy | Chrome privacy, safe browsing, and data collection defaults | all | x | x | x |
| user | browser | Chrome Profile | Chrome ephemeral profiles, no history, no sync | all | x |   |   |
| user | browser | Chrome Sign In | Allow only ZuidWest Google accounts for Chrome sign-in on personal systems | all |   | x |   |
| user | browser | Chrome UI | Block Chrome notifications/popups and remove promotional UI | all | x | x | x |
| user | browser | Edge Autofill | Disable Edge autofill and data import | all | x |   |   |
| user | browser | Edge Developer Tools | Disable Edge Developer Tools (F12) | all | x |   |   |
| user | browser | Edge Disable Sign In | Disable Edge sign-in on shared and dedicated systems | all | x |   | x |
| user | browser | Edge Extensions | Block all Edge extension installations | all | x |   |   |
| user | browser | Edge Privacy | Edge tracking prevention and security | all | x | x | x |
| user | browser | Edge Profile | Edge ephemeral profiles, no history, no sync | all | x |   |   |
| user | browser | Edge Sign In | Allow only ZuidWest work/school accounts for Edge sign-in on personal systems | all |   | x |   |
| user | browser | Edge UI | Disable Edge bloatware UI elements and set homepage to zuidwestupdate.nl | all | x | x | x |
| user | personalization | Set Wallpaper Black | Set solid black wallpaper for dedicated systems | all |   |   | x |
| user | personalization | Set Wallpaper Branded | Set branded ZuidWest wallpaper for shared and personal systems | all | x | x |   |
| user | security | Disable Command Prompt | Disable Command Prompt for non-admin users | all | x |   |   |
| user | security | Disable Control Panel | Disable Control Panel and Settings app for non-admin users | all | x |   |   |
| user | security | Disable Network Settings | Disable network connection property changes for non-admin users | all | x |   |   |
| user | security | Disable PowerShell | Disable PowerShell for non-admin users | all | x |   |   |
| user | security | Disable Registry Editor | Disable Registry Editor for non-admin users | all | x |   |   |
| user | security | Disable Run Dialog | Disable Run dialog (Win+R) for non-admin users | all | x |   |   |
| user | security | Disable Task Manager | Disable Task Manager for non-admin users | all | x |   |   |
| user | security | Disable Workstation Lock | Remove the Lock command and disable Win+L for non-admin users | all |   |   | x |
| user | security | Disable Workstation Lock Production Shared | Remove the Lock command and disable Win+L on shared radio and TV production systems | radio, tv | x |   |   |
<!-- END_POLICY_MATRIX -->

## File Format

Registry policy files (`.txt`) use LGPO.exe text format:

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

Local security policy overrides use security template (`.inf`) format and are applied with `LGPO.exe /s`. Use this format for settings that the Microsoft security baseline stores in the local security policy database.

## Adding New Policies

1. Create a new directory under `system/` or `user/`
2. Add registry policy `.txt` file(s) in LGPO format or local security policy `.inf` file(s) in security template format
3. Add a `README.md` documenting each policy setting
4. Register the policy in `config.json` with appropriate scopes

## References

- [LGPO Documentation](https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/security-compliance-toolkit-10#lgpo-exe)
- [Group Policy Settings Reference](https://admx.help/)

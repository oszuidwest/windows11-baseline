# Windows 11 Baseline

Baseline configuration for **Windows 11 24H2 Enterprise LTSC** computers at Streekomroep ZuidWest. Refactored from [Windows 10 Baseline](https://github.com/oszuidwest/windows10-baseline).

## Quick Start

Run as Administrator:

```powershell
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/oszuidwest/windows11-baseline/main/install.ps1' -UseBasicParsing).Content | Invoke-Expression }`"" -Verb RunAs
```

The installer prompts for:
- **System purpose** (radio, tv, editorial, plain) - validated input
- **System ownership** (shared, personal, dedicated) - validated input
- **Computer name**
- **Workgroup name**
- **User password**
- **DWService agent code** (optional, leave empty to skip)

## Configuration Options

### Purpose

| Purpose | Description | Auto-login Username |
|---------|-------------|---------------------|
| Radio | Radio production workstations | Studio Gebruiker |
| TV | Video editing workstations | Studio Gebruiker |
| Editorial | Journalism/office workstations | Redactie Gebruiker |
| Plain | Basic workstations without specific software | (none) |

### Ownership

| Ownership | Description | Auto-login | Microsoft Store |
|-----------|-------------|------------|-----------------|
| Shared | Shared computers with restricted access | Yes (if not plain) | Blocked |
| Personal | Company-issued laptops for employees | No | Allowed |
| Dedicated | Single-function systems (e.g., playout servers) | No | Allowed |

## Application Matrix

|                 | Radio | TV | Editorial | Plain |
|-----------------|:-----:|:--:|:---------:|:-----:|
| Audacity        | x     |    | x         |       |
| Creative Cloud  |       | x  |           |       |
| LibreOffice     | x     | x  |           |       |
| MS Teams        |       |    | x         |       |
| Pinta           |       |    | x         |       |
| Thunderbird     | x     |    |           |       |
| VLC             | x     | x  | x         |       |

Applications are installed via **winget**. On LTSC systems (which lack Microsoft Store), winget is automatically installed with all required dependencies from the official GitHub releases.

### Shared Systems

Shared systems also receive:
- **WhatsApp Web shortcut** on Public Desktop (Edge InPrivate mode, no data stored)
- **Branded wallpaper** at `C:\Windows\deploy\wallpaper.png` (locked, cannot be changed)
- **Microsoft Store disabled** including web-based app installer protocol
- **Edge lockdown** - ephemeral profiles, no extensions, no developer tools, no autofill
- **System tools blocked** - Command Prompt, PowerShell, Registry Editor, Run dialog (Win+R)
- **Privacy hardening** - clipboard history disabled, no data persistence

### Dedicated Systems

Dedicated systems (e.g., playout servers) receive:
- **BGInfo desktop overlay** showing computer name, IP addresses, network config, system specs (auto-starts at login)
- **Black wallpaper** (clean, distraction-free, locked)

## Regional Settings

All systems are configured for the Netherlands:

| Setting | Value |
|---------|-------|
| Timezone | W. Europe Standard Time (Amsterdam) |
| System Locale | nl-NL (Dutch) |
| Regional Format | dd-MM-yyyy, HH:mm, comma decimal |
| NTP Servers | 0-3.nl.pool.ntp.org |
| Home Location | Netherlands (GeoId 176) |

## Remote Management

### DWService

[DWService](https://www.dwservice.net/) provides free remote access to managed systems. When a DWService agent code is provided during installation:

1. The DWAgent installer is downloaded from dwservice.net
2. Agent is installed silently with the provided code
3. System appears in your DWService dashboard for remote access

To get an agent code:
1. Create an account at [dwservice.net](https://www.dwservice.net/)
2. Add a new agent and select "Create an installation with the following code"
3. Copy the code and provide it during baseline installation

Leave the agent code empty during installation to skip DWService.

## Studio Configuration

Radio and TV systems receive additional configuration for broadcast environments:

| Setting | Description |
|---------|-------------|
| System sounds disabled | All Windows sounds muted via Default User registry to prevent audio leaks |

## Power Settings

| Setting | AC Power | Battery (DC) |
|---------|----------|--------------|
| Monitor timeout | 30 min | 30 min |
| Disk timeout | Disabled | Disabled |
| Standby | Never | 60 min |
| Hibernate | Disabled | Disabled |

## Policy Framework

Policies are applied via LGPO.exe based on system purpose and ownership. Configuration is defined in `policies/config.json`.

### Policy Summary

| Category | Policy | Shared | Personal | Dedicated |
|----------|--------|:------:|:--------:|:---------:|
| **Bloatware** | Disable web search in Start | x | x | x |
| | Disable Widgets | x | x | x |
| | Disable Spotlight tips | x | x | x |
| | Disable Game Bar | x | x | x |
| | Disable Copilot | x | x | x |
| **Microsoft Store** | Disable Store + app installer protocol | x | | |
| **Microsoft Account** | Disable MS Account auth | x | | |
| **OneDrive** | Disable sync | x | | |
| **Security** | Disable autorun | x | x | x |
| | Hide shutdown button | x | | |
| **Privacy** | Disable tracking/telemetry | x | x | x |
| | Disable clipboard history | x | | |
| | Disable activity history | x | x | x |
| **Logon** | Disable logon animations | x | x | x |
| **OOBE** | Skip privacy wizard | x | x | x |
| **Updates** | Auto-update daily 3:00 AM | x | x | x |
| **Edge** | Homepage zuidwestupdate.nl | x | x | x |
| | Tracking prevention | x | x | x |
| | Disable Copilot in Edge | x | x | x |
| | Ephemeral profiles | x | | |
| | Disable autofill | x | | |
| | Disable developer tools (F12) | x | | |
| | Block extension installs | x | | |
| **Wallpaper** | Branded (ZuidWest) | x | | |
| | Black background | | | x |
| **User Security** | Disable Command Prompt | x | | |
| | Disable Registry Editor | x | | |
| | Disable PowerShell | x | | |
| | Disable Run dialog (Win+R) | x | | |

See [`policies/README.md`](policies/README.md) for the full policy matrix and documentation.

## Repository Structure

```
windows11-baseline/
├── install.ps1                 # Main installer (downloads repo, runs scripts)
├── bin/
│   └── LGPO.exe               # Microsoft Local Group Policy Object utility
├── config/
│   └── bginfo.bgi             # BGInfo layout configuration (optional)
├── policies/
│   ├── config.json            # Policy-to-scope mapping
│   ├── config.schema.json     # JSON schema for validation
│   ├── system/                # Computer policies (HKLM)
│   │   ├── bloatware/
│   │   ├── logon-experience/
│   │   ├── microsoft-account/
│   │   ├── microsoft-store/   # Store blocking for shared systems
│   │   ├── onedrive/
│   │   ├── oobe/
│   │   ├── privacy/
│   │   ├── security/
│   │   └── windows-update/
│   └── user/                  # User policies (HKCU, non-admin only)
│       ├── browser/
│       ├── personalization/
│       └── security/
├── scripts/
│   ├── _debloat.ps1           # Remove Windows bloatware apps (Copilot, Store, etc.)
│   ├── apps.ps1               # Install winget (if needed) + apps based on purpose
│   ├── bginfo.ps1             # BGInfo system info overlay (dedicated only)
│   ├── dwservice.ps1          # DWService remote access agent
│   ├── policies.ps1           # Apply policies via LGPO
│   ├── power.ps1              # Power settings (monitor, standby, hibernate)
│   ├── sounds.ps1             # Disable system sounds (Radio/TV only)
│   ├── time.ps1               # Timezone, regional settings, NTP (Netherlands)
│   ├── updates.ps1            # Check and install Windows updates
│   ├── users.ps1              # Create user, configure auto-login
│   └── workgroupname.ps1      # Set computer/workgroup name
```

## Execution Flow

1. `install.ps1` downloads repository to `C:\Windows\deploy`
2. Validates user input (purpose/ownership must be valid)
3. Executes all scripts in `scripts/` alphabetically:
   - `_debloat.ps1` - Removes 29 bloatware apps (Copilot, Store, Teams, etc.)
   - `apps.ps1` - Installs winget (LTSC) + applications via winget
   - `bginfo.ps1` - Sets up BGInfo (dedicated systems only)
   - `dwservice.ps1` - Installs remote access (if agent code provided)
   - `policies.ps1` - Downloads wallpaper, applies Group Policies
   - `power.ps1` - Configures power settings
   - `sounds.ps1` - Disables system sounds (Radio/TV only)
   - `time.ps1` - Sets timezone, locale, NTP to Netherlands
   - `updates.ps1` - Installs Windows updates
   - `users.ps1` - Creates user account, configures auto-login
   - `workgroupname.ps1` - Sets computer and workgroup name

## LTSC Compatibility

Windows 11 Enterprise LTSC does not include Microsoft Store or winget. The `apps.ps1` script automatically:

1. Detects if winget is missing
2. Downloads the official dependencies package from GitHub releases
3. Installs VCLibs, WindowsAppRuntime (architecture-aware: x64 or ARM64)
4. Installs winget with proper license for all users
5. Proceeds with application installation

## Development

### Linting

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning,Error -ExcludeRule PSReviewUnusedParameter
```

### Testing

Must be run as Administrator on a Windows 11 machine.

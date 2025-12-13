# Windows 11 Baseline

Baseline configuration for **Windows 11 24H2 Enterprise LTSC** computers at Streekomroep ZuidWest. Refactored from [Windows 10 Baseline](https://github.com/oszuidwest/windows10-baseline).

## Quick Start

Run as Administrator:

```powershell
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/oszuidwest/windows11-baseline/main/install.ps1' -UseBasicParsing).Content | Invoke-Expression }`"" -Verb RunAs
```

The installer prompts for:
- **System purpose** (radio, tv, editorial, plain)
- **System ownership** (shared, personal, dedicated)
- **Computer name**
- **Workgroup name**
- **User password**
- **Create user with auto-login?** (dedicated only)
- **Username** (if creating user)
- **DWService agent code** (optional)

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
| Dedicated | Single-function systems (e.g., playout servers) | Optional (custom user) | Allowed |

## Application Matrix

|                 | Radio | TV | Editorial | Plain |
|-----------------|:-----:|:--:|:---------:|:-----:|
| Audacity        | x     |    | x         |       |
| Creative Cloud  |       | x  |           |       |
| LibreOffice     | x     | x  |           |       |
| MS Teams        |       |    | x         |       |
| Pinta           |       |    | x         |       |
| Spotify         | x     |    |           |       |
| Thunderbird     | x     |    |           |       |
| VLC             | x     | x  | x         |       |

Applications are installed via **winget**, except Spotify which uses a direct download due to winget limitations in admin context. On LTSC systems (which lack Microsoft Store), winget is automatically installed with all required dependencies from the official GitHub releases.

### Shared Systems

Shared systems also receive:
- **WhatsApp Web shortcut** on Public Desktop (Edge InPrivate mode, no data stored)
- **Branded wallpaper** at `C:\Windows\deploy\wallpaper.png` (locked, cannot be changed)
- **Microsoft Store blocked** via AppLocker (blocks Store app and web installer from get.microsoft.com)
- **Edge lockdown** - ephemeral profiles, no extensions, no developer tools, no autofill
- **System tools blocked** - Command Prompt, PowerShell, Registry Editor, Run dialog (Win+R), Task Manager
- **Settings blocked** - Control Panel, Settings app, network connection properties
- **Privacy hardening** - clipboard history disabled, no data persistence

### Dedicated Systems

Dedicated systems (e.g., playout servers) receive:
- **Black wallpaper** (clean, distraction-free, locked)

### AppLocker

On Windows 11 24H2, the traditional GPO "Turn off the Store application" is [no longer honored](https://learn.microsoft.com/en-us/answers/questions/5563743/windows-11-24h2-cannot-block-microsoft-store-ignor). Additionally, Copilot cannot be reliably blocked via GPO in 24H2. This baseline uses **AppLocker** to block unwanted apps based on ownership. The policy XML is generated dynamically at runtime:

| Ownership | Blocked Apps |
|-----------|--------------|
| Shared | Store, Copilot, StoreInstaller.exe |
| Dedicated | Copilot only |
| Personal | Nothing blocked |

The Application Identity service is automatically enabled by the script.

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

Optional [DWService](https://www.dwservice.net/) remote access. Provide an agent code during installation to enable, or leave empty to skip.

## Sound Configuration

All systems have Windows sounds disabled.

## Power Settings

| Setting | AC Power | Battery (DC) |
|---------|----------|--------------|
| Monitor timeout | 30 min | 30 min |
| Disk timeout | Disabled | Disabled |
| Standby | Never | 60 min |
| Hibernate | Disabled | Disabled |

## Policy Framework

Policies are applied via LGPO.exe based on system purpose and ownership. Configuration is defined in `policies/config.json`. See [`policies/README.md`](policies/README.md) for the full policy matrix.

## Security Hardening

All systems receive defense-in-depth hardening beyond Windows 11 24H2 defaults. Attack surface reduction is achieved by disabling the Remote Registry service, blocking AutoRun on all drive types, and removing pre-installed bloatware. Protocol hardening enforces NTLMv2-only authentication (level 5) to prevent downgrade attacks. Windows Defender Network Protection provides real-time blocking of connections to known malicious and phishing domains. Telemetry is disabled to minimize data exposure. These measures complement the SMB signing and LSA protection already enabled by default in 24H2.

## LTSC Compatibility

LTSC lacks winget. The installer automatically installs it with all dependencies from GitHub releases.

## Development

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning,Error -ExcludeRule PSReviewUnusedParameter
```

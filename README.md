# Windows 11 Baseline

Baseline configuration for **Windows 11 24H2 Enterprise LTSC** computers at Streekomroep ZuidWest. Refactored from [Windows 10 Baseline](https://github.com/oszuidwest/windows10-baseline).

## Quick Start

### Fresh Installation

Run as Administrator:

```powershell
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/oszuidwest/windows11-baseline/main/install.ps1' -OutFile `$env:TEMP\install.ps1; & `$env:TEMP\install.ps1 }`"" -Verb RunAs
```

The installer is interactive and prompts for:
- **System purpose** (radio, tv, editorial, plain)
- **System ownership** (shared, personal, dedicated)
- **Computer name**
- **Workgroup name**
- **User password**
- **Username** (personal/dedicated only)
- **Create user with auto-login?** (dedicated only)
- **DWService agent code** (optional)

Deployment values are not accepted as command-line parameters. Use the prompts; `-OnlyRun` is the only supported installer option.

### Updating Existing Systems

Use the `-OnlyRun` parameter to selectively run specific scripts on already-deployed systems. The installer still prompts for any values needed by the selected scripts:

```powershell
# Update policies only (prompts for purpose and ownership)
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { iwr 'https://raw.githubusercontent.com/oszuidwest/windows11-baseline/main/install.ps1' -OutFile `$env:TEMP\install.ps1; & `$env:TEMP\install.ps1 -OnlyRun 'policies' }`"" -Verb RunAs

# Update multiple components
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { iwr 'https://raw.githubusercontent.com/oszuidwest/windows11-baseline/main/install.ps1' -OutFile `$env:TEMP\install.ps1; & `$env:TEMP\install.ps1 -OnlyRun 'policies','hardening' }`"" -Verb RunAs
```

Available scripts: `debloat`, `securitybaseline`, `applocker`, `apps`, `dwservice`, `hardening`, `policies`, `policyupdate`, `power`, `sounds`, `time`, `updates`, `users`, `workgroupname`

### Auto-Update for Policies

A full install also registers an auto-update Scheduled Task (`\ZuidWest\PolicyAutoUpdate`) so policy changes pushed to `main` propagate to every deployed machine without a manual re-run.

- **Triggers:** system startup, any user logon, hourly thereafter.
- **What it does:** asks the GitHub API for the current `main` commit SHA. If it matches the last applied SHA, exits silently. If different, downloads the archive for that SHA into `C:\ProgramData\ZuidWest\policy-update\staging`, then re-runs `policies` and `applocker` against that staged copy via the `$env:WINDOWS11_BASELINE_DEPLOY_PATH` override (so it never touches `C:\Windows\deploy`).
- **State and logs:**
  - `C:\ProgramData\ZuidWest\policy-update\state.json` - purpose, ownership, repo coordinates, last applied SHA
  - `C:\ProgramData\ZuidWest\policy-update\update.ps1` - the auto-updater payload (self-refreshes from `scripts/lib/policy-auto-updater.ps1` on each successful apply)
  - `C:\ProgramData\ZuidWest\Logs\policy-auto-update.log` - rotated at 5 MB

To refresh the task or change which scripts get re-applied, re-run `install.ps1 -OnlyRun policyupdate`. To disable, delete the Scheduled Task: `Unregister-ScheduledTask -TaskPath '\ZuidWest\' -TaskName 'PolicyAutoUpdate' -Confirm:$false`.

## Configuration Options

### Purpose

| Purpose | Description | Auto-login Username |
|---------|-------------|---------------------|
| Radio | Radio production workstations | Studio Gebruiker |
| TV | Video editing workstations | Studio Gebruiker |
| Editorial | Journalism/office workstations | Redactie Gebruiker |
| Plain | Basic workstations without specific software | (none) |

### Ownership

| Ownership | Description | User | Auto-login | Microsoft Store |
|-----------|-------------|------|------------|-----------------|
| Shared | Shared computers with restricted access | Purpose-based | Yes (if not plain) | Blocked |
| Personal | Company-issued laptops for employees | Custom | No | Blocked |
| Dedicated | Single-function systems (e.g., playout servers) | Custom (optional) | Optional | Blocked |

The Microsoft Store app is removed for all ownerships via the debloat phase (`Microsoft.WindowsStore` is in the global removal list, including its provisioned package so it does not return for new users). Shared systems additionally block `StoreInstaller.exe` (the web installer from `get.microsoft.com`) via AppLocker as defense-in-depth.

## Application Matrix

|                 | Radio | TV | Editorial | Plain |
|-----------------|:-----:|:--:|:---------:|:-----:|
| Audacity        | x     |    | x         |       |
| Creative Cloud  |       | x  |           |       |
| LibreOffice     | x     | x  |           |       |
| MS Office       |       |    | x         |       |
| MS Teams        |       |    | x         |       |
| Pinta           |       |    | x         |       |
| Spotify         | x     |    |           |       |
| Thunderbird     | x     |    |           |       |
| VLC             | x     | x  | x         |       |

Personal systems additionally receive Google Chrome regardless of purpose.

Applications are installed via **winget**, except Spotify and MS Office which use direct downloads. Spotify has winget limitations in admin context; Office uses the Office Deployment Tool with a custom config (`config/office.xml`) for Dutch language and excluded apps. On LTSC systems (which lack Microsoft Store), winget is automatically installed with all required dependencies from the official GitHub releases.

### Shared Systems

Shared systems also receive:
- **WhatsApp Web shortcut** on Public Desktop (Edge InPrivate mode, no data stored)
- **Branded wallpaper** at `C:\ProgramData\ZuidWest\wallpaper\wallpaper.png` (locked, cannot be changed)
- **Microsoft Store and StoreInstaller.exe blocked** via AppLocker (defense-in-depth on top of the debloat-phase appx removal that applies to all systems)
- **Edge/Chrome lockdown** - ephemeral profiles, no extensions, no developer tools, no autofill
- **System tools blocked** - Command Prompt, PowerShell, Registry Editor, Run dialog (Win+R), Task Manager
- **Settings blocked** - Control Panel, Settings app, network connection properties
- **Privacy hardening** - clipboard history disabled, no data persistence

### Dedicated Systems

Dedicated systems (e.g., playout servers) receive:
- **Black wallpaper** (clean, distraction-free, locked)

### AppLocker

On Windows 11 24H2, the traditional GPO "Turn off the Store application" is [no longer honored](https://learn.microsoft.com/en-us/answers/questions/5563743/windows-11-24h2-cannot-block-microsoft-store-ignor). Additionally, Copilot cannot be reliably blocked via GPO in 24H2. This baseline uses **AppLocker** to block unwanted apps based on ownership. The policy XML lives as checked-in templates in `policies/applocker/` (`shared.xml`, `dedicated.xml`); `scripts/applocker.ps1` selects the matching template and applies it via `AppLockerPolicyTool.exe`:

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

Edge and Chrome sign-in are disabled on shared and dedicated systems. Personal
systems allow only ZuidWest work/school account addresses.

## Security Hardening

All systems first receive the official **Microsoft Windows 11 v24H2 Security Baseline** from the Microsoft Security Compliance Toolkit, applied locally with LGPO.exe. The package is downloaded from Microsoft at deployment time and verified with a pinned SHA-256 hash before use. The Microsoft BitLocker GPO is intentionally skipped because it blocks writing to removable drives that are not BitLocker-protected; editorial and camera workflows need normal access to SD cards. ZuidWest applies a removable-media-safe BitLocker hardening policy afterwards.

Additional defense-in-depth hardening beyond Windows 11 24H2 defaults disables the Remote Registry service, blocks AutoRun on all drive types, and removes pre-installed bloatware. Protocol hardening enforces NTLMv2-only authentication (level 5) to prevent downgrade attacks. Windows Defender Network Protection provides real-time blocking of connections to known malicious and phishing domains. Telemetry is disabled to minimize data exposure. These measures complement the SMB signing and LSA protection already enabled by default in 24H2.

## LTSC Compatibility

LTSC lacks winget. The installer automatically installs it with all dependencies from GitHub releases.

## Development

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning,Error -ExcludeRule PSReviewUnusedParameter
```

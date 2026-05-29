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

Deployment values are not accepted as command-line parameters; `-OnlyRun` is the only supported installer option.

### Updating Existing Systems

`-OnlyRun` re-runs specific scripts on an already-deployed system (pass one or more names, comma-separated). The installer still prompts for any values those scripts need:

```powershell
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { iwr 'https://raw.githubusercontent.com/oszuidwest/windows11-baseline/main/install.ps1' -OutFile `$env:TEMP\install.ps1; & `$env:TEMP\install.ps1 -OnlyRun 'policies','hardening' }`"" -Verb RunAs
```

Available scripts: `debloat`, `securitybaseline`, `applocker`, `apps`, `dwservice`, `hardening`, `policies`, `policyupdate`, `power`, `sounds`, `time`, `updates`, `users`, `workgroupname`

### Auto-Update for Policies

A full install also registers an auto-update Scheduled Task (`\ZuidWest\PolicyAutoUpdate`) so policy changes pushed to `main` propagate to every deployed machine without a manual re-run.

- **Triggers:** system startup (15 min jitter), any user logon (5 min jitter), hourly thereafter (60 min jitter).
- **What it does:** reads the public commits.atom feed at `https://github.com/oszuidwest/windows11-baseline/commits/main.atom` (not the REST API, so no 60 req/h/IP quota) to learn the current `main` commit SHA. If it matches the last applied SHA, exits silently. Otherwise it downloads that SHA's archive into `C:\ProgramData\ZuidWest\policy-update\staging` and re-runs `policies` and `applocker` against the staged copy via the `$env:WINDOWS11_BASELINE_DEPLOY_PATH` override. On rate-limiting (e.g. a fleet behind one NAT), the backoff window from the response headers is persisted and further checks skip until it passes.
- **Runtime layout** under `C:\ProgramData\ZuidWest`:
  - `deploy\` - current full-install deploy cache
  - `policy-update\state.json` - schema version, enabled flag, repo coordinates, purpose/ownership, scripts to re-apply, and SHA/timestamp tracking (last applied, last self-update, last check, backoff)
  - `policy-update\update.ps1` - auto-updater payload (self-refreshes from `scripts/lib/policy-auto-updater.ps1` on each successful apply)
  - `Logs\policy-auto-update.log` - rotated at 5 MB

Re-run `install.ps1 -OnlyRun policyupdate` to refresh the task or change which scripts get re-applied. To pause auto-update without deleting the task, set `enabled` to `false` in `state.json` (set back to `true` to resume). To disable fully: `Unregister-ScheduledTask -TaskPath '\ZuidWest\' -TaskName 'PolicyAutoUpdate' -Confirm:$false`.

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

The Microsoft Store (`Microsoft.WindowsStore` plus its provisioned package, so it does not return for new users) is removed for all ownerships during the debloat phase. Shared systems additionally block `StoreInstaller.exe` (the web installer from `get.microsoft.com`) via AppLocker as defense-in-depth.

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

Apps install via **winget**, except Spotify (winget fails in admin context, so it uses the standalone installer) and MS Office (Office Deployment Tool with `config/office.xml`: Dutch language, custom exclusions). LTSC has no Microsoft Store, so winget itself is auto-installed with all dependencies from the official GitHub releases.

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

On Windows 11 24H2, the GPO "Turn off the Store application" is [no longer honored](https://learn.microsoft.com/en-us/answers/questions/5563743/windows-11-24h2-cannot-block-microsoft-store-ignor) and Copilot cannot be reliably blocked via GPO either, so this baseline uses **AppLocker** instead. `scripts/applocker.ps1` selects the matching template from `policies/applocker/` (`shared.xml`, `dedicated.xml`, `personal.xml`) and applies it via `AppLockerPolicyTool.exe`:

| Ownership | Blocked Apps |
|-----------|--------------|
| Shared | Store, Copilot, StoreInstaller.exe |
| Dedicated | Copilot only |
| Personal | Nothing blocked (reset template clears any rules left by earlier shared/dedicated deployments) |

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

Policies are applied via LGPO.exe based on purpose and ownership, configured in `policies/config.json`. See [`policies/README.md`](policies/README.md) for the full matrix.

Edge and Chrome sign-in are disabled on shared and dedicated systems; personal systems allow only ZuidWest work/school account addresses.

## Security Hardening

All systems first receive the official **Microsoft Windows 11 v24H2 Security Baseline** (Microsoft Security Compliance Toolkit), applied locally with LGPO.exe. The package is downloaded at deployment time and verified against a pinned SHA-256 hash. Microsoft's BitLocker GPO is intentionally skipped because it blocks writes to non-BitLocker removable drives, breaking editorial and camera SD-card workflows; ZuidWest applies a removable-media-safe BitLocker policy afterwards.

Additional defense-in-depth beyond 24H2 defaults: Remote Registry disabled, AutoRun blocked on all drive types, pre-installed bloatware removed, NTLMv2-only authentication (level 5) to prevent downgrade attacks, Windows Defender Network Protection enabled (real-time blocking of malicious/phishing domains), and telemetry disabled. SMB signing and LSA protection are already on by default in 24H2.

## LTSC Compatibility

LTSC lacks winget. The installer automatically installs it with all dependencies from GitHub releases.

## Development

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning,Error -ExcludeRule PSReviewUnusedParameter
```

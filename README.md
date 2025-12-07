# Windows 11 Baseline

Baseline configuration for **Windows 11 24H2 Enterprise LTSC** computers at Streekomroep ZuidWest. Refactored from [Windows 10 Baseline](https://github.com/oszuidwest/windows10-baseline).

## Quick Start

Run as Administrator:

```powershell
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/oszuidwest/windows11-baseline/main/install.ps1' -UseBasicParsing).Content | Invoke-Expression }`"" -Verb RunAs
```

The installer prompts for: computer name, workgroup name, user password, system purpose, system ownership, and optionally a DWService agent code.

## Configuration Options

### Purpose

| Purpose | Description |
|---------|-------------|
| Radio | Radio production workstations |
| TV | Video editing workstations |
| Editorial | Journalism/office workstations |
| Plain | Basic workstations without specific software |

### Ownership

| Ownership | Description |
|-----------|-------------|
| Shared | Shared computers (auto-login enabled) |
| Personal | Company-issued laptops for employees |
| Dedicated | Single-function systems (e.g., playout servers) |

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

### Shared Systems

Shared systems also receive:
- **WhatsApp Web shortcut** on desktop (Edge InPrivate mode, no data stored)
- **Branded wallpaper** (ZuidWest branding, locked)

### Dedicated Systems

Dedicated systems (e.g., playout servers) receive:
- **BGInfo desktop overlay** showing computer name, IP addresses, network config, system specs
- **Black wallpaper** (clean, distraction-free)

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
| System sounds disabled | All Windows sounds muted to prevent audio leaks during broadcasts |

## Policy Framework

Policies are applied via LGPO.exe based on system purpose and ownership. Configuration is defined in `policies/config.json`.

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
│   ├── _debloat.ps1           # Remove Windows bloatware apps
│   ├── apps.ps1               # Install apps based on purpose
│   ├── bginfo.ps1             # BGInfo system info overlay (dedicated only)
│   ├── dwservice.ps1          # DWService remote access agent
│   ├── policies.ps1           # Apply policies via LGPO
│   ├── power.ps1              # Power settings (30min monitor, no standby)
│   ├── sounds.ps1             # Disable system sounds (Radio/TV only)
│   ├── time.ps1               # NTP config (nl.pool.ntp.org), timezone, regional settings
│   ├── updates.ps1            # Check and install Windows updates
│   ├── users.ps1              # Create user, configure auto-login
│   └── workgroupname.ps1      # Set computer/workgroup name
```

## Execution Flow

1. `install.ps1` downloads repository to `C:\Windows\deploy`
2. Executes all scripts in `scripts/` alphabetically with user-provided parameters
3. `apps.ps1` installs applications using winget
4. `bginfo.ps1` sets up desktop system info (dedicated systems only)
5. `dwservice.ps1` installs remote access agent (if agent code provided)
6. `policies.ps1` reads `config.json`, filters by purpose/ownership, applies via LGPO
7. `updates.ps1` checks for and installs Windows updates

## Development

### Linting

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning,Error -ExcludeRule PSReviewUnusedParameter
```

### Testing

Must be run as Administrator on a Windows 11 machine.

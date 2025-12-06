# Windows 11 Baseline

Baseline configuration for **Windows 11 24H2 Enterprise LTSC** computers at Streekomroep ZuidWest. Refactored from [Windows 10 Baseline](https://github.com/oszuidwest/windows10-baseline).

## Quick Start

Run as Administrator:

```powershell
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/oszuidwest/windows11-baseline/main/install.ps1' -UseBasicParsing).Content | Invoke-Expression }`"" -Verb RunAs
```

The installer prompts for: computer name, workgroup name, user password, system purpose, and system ownership.

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

## Policy Framework

Policies are applied via LGPO.exe based on system purpose and ownership. Configuration is defined in `policies/config.json`.

### Policy Matrix

| Policy | Description | Shared | Personal | Dedicated |
|--------|-------------|:------:|:--------:|:---------:|
| Disable web search | Remove Bing from Start menu | x | x | x |
| Disable logon animations | Skip first-run animations | x | x | x |
| Disable Microsoft Account | Block MS account login | x | | |
| Disable OneDrive sync | Prevent cloud sync | x | | |
| Disable OOBE privacy | Skip privacy wizard | x | x | x |
| Disable tracking | Telemetry, location, ads | x | x | x |
| Disable Widgets | Remove Widgets panel | x | x | x |
| Windows Update | Auto-update daily at 3 AM | x | x | x |

### Adding Policies

1. Create policy file in `policies/system/<category>/<name>.txt` (LGPO format)
2. Add README.md documenting the policy
3. Register in `policies/config.json` with purpose/ownership scopes

See `policies/README.md` for detailed documentation.

## Repository Structure

```
windows11-baseline/
├── install.ps1                 # Main installer (downloads repo, runs scripts)
├── bin/
│   └── LGPO.exe               # Microsoft Local Group Policy Object utility
├── policies/
│   ├── config.json            # Policy-to-scope mapping
│   ├── config.schema.json     # JSON schema for validation
│   └── system/                # Computer policies (HKLM)
│       ├── bloatware/
│       ├── logon-experience/
│       ├── microsoft-account/
│       ├── onedrive/
│       ├── oobe/
│       ├── privacy/
│       ├── windows-feeds/
│       └── windows-update/
├── scripts/
│   ├── _debloat.ps1           # Remove Windows bloatware apps
│   ├── apps.ps1               # Install apps based on purpose
│   ├── policies.ps1           # Apply policies via LGPO
│   ├── power.ps1              # Power settings (30min monitor, no standby)
│   ├── time.ps1               # NTP config (nl.pool.ntp.org)
│   ├── users.ps1              # Create user, configure auto-login
│   └── workgroupname.ps1      # Set computer/workgroup name
└── installers/                 # App installer scripts
```

## Execution Flow

1. `install.ps1` downloads repository to `C:\Windows\deploy`
2. Installs Chocolatey package manager
3. Executes all scripts in `scripts/` with user-provided parameters
4. `policies.ps1` reads `config.json`, filters by purpose/ownership, applies via LGPO

## Development

### Linting

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning,Error -ExcludeRule PSReviewUnusedParameter
```

### Testing

Must be run as Administrator on a Windows 11 machine.

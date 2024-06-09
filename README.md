# Windows 11 Baseline

This repository is a comprehensive refactor of [Windows 10 Baseline](https://github.com/oszuidwest/windows10-baseline). It serves as the baseline configuration for Windows 11 computers owned by Streekomroep ZuidWest.


**⚠️ This project is still being developed. The goal is to customize the configuration for the computer’s intended use and ownership. It is not yet complete, fully tested, or secure. We are waiting for the release of Windows 11 24H2 to start practical tests.**

## Purpose
- Radio (Radio production)
- TV (Video editing)
- Editorial (Journalism)
- Plain

## Ownership
- Shared (Shared computers in studios and editing suites)
- Owned (Company-issued laptops for employees)
- Dedicated (e.g., playout servers)

```powershell
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/oszuidwest/windows11-baseline/main/install.ps1' -UseBasicParsing).Content | Invoke-Expression }`"" -Verb RunAs
```

### Application Mapping

|                 | Radio | TV | Editorial | Plain |
|-----------------|-------|----|-----------|-------|
| 7Zip            | Y     | Y  | Y         | N     |
| Audacity        | Y     | N  | Y         | N     |
| Creative Cloud  | N     | Y  | N         | N     |
| LibreOffice     | Y     | Y  | Y         | N     |
| MS Teams        | N     | N  | Y         | N     |
| Pintra          | N     | N  | Y         | N     |
| Thunderbird     | Y     | N  | N         | N     |
| VLC             | Y     | Y  | Y         | N     |

### System Policy Mapping

|                              | Shared     | Personal   | Dedicated  |
|------------------------------|------------|------------|------------|
| Windows Update               | Hard       | Hard       | Disabled   |
| Edge                         | Restricted | Flexible   | Flexible   |
| Microsoft Account login/sync | Disabled   | Allowed    | Disabled   |

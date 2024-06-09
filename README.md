# Windows 11 Baseline

This repository is a comprehensive refactor of [Windows 10 Baseline](https://github.com/oszuidwest/windows10-baseline). It serves as the baseline configuration for Windows 11 computers owned by Streekomroep ZuidWest.

**⚠️ This project is currently under development. The aim is to customize the configuration according to the computer's intended use and ownership. It remains entirely untested and is based on theoretical concepts. We are awaiting the release of Windows 11 24H2 to conduct practical tests.**

## Purpose
- Radio (Radio production)
- TV (Video editing)
- Editorial (Journalism)
- Plain

## Ownership
- Shared (Shared computers in studios and editing suites)
- Owned (Company-issued laptops for employees)
- Dedicated (e.g., playout servers)

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

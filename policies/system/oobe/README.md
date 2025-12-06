# OOBE (Out-of-Box Experience) Policies

These policies customize the Windows setup and first-run experience.

## Policies

### `disable-privacy-experience.txt`

Disables the privacy settings screen during Windows setup.

| Setting | Value | Description |
|---------|-------|-------------|
| `DisablePrivacyExperience` | 1 | Skips the "Choose privacy settings for your device" screen during OOBE and new user creation |

## Why

- Streamlines automated deployments
- Ensures consistent privacy settings across all machines
- Prevents users from accidentally enabling unwanted telemetry
- Privacy settings are configured via other policies instead

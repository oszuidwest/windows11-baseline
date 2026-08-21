# Security Policies

System hardening policies for malware prevention, authentication security, and attack surface reduction.

## Policies

### `allow-local-firewall-rules.txt`

Allows administrators to add local Windows Defender Firewall rules when the active network uses the Public profile. This overrides the Microsoft security baseline setting that otherwise ignores local firewall rules on public networks. It does not disable the firewall or change its default inbound and outbound actions.

| Setting | Value | Effect |
|---------|-------|--------|
| `PublicProfile\\AllowLocalPolicyMerge` | 1 | Merge locally created firewall rules into the effective public-profile policy |

### `disable-autorun.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `NoDriveTypeAutoRun` | 255 | Disables AutoRun/AutoPlay for all drive types |

### `relax-password-policy.inf`

Applies to every system and overrides the minimum length and complexity requirements from the Microsoft Windows 11 security baseline. The deployment still requires a non-empty password when creating an account.

| Setting | Value | Effect |
|---------|-------|--------|
| `MinimumPasswordLength` | 0 | Removes the Windows minimum password length requirement |
| `PasswordComplexity` | 0 | Allows passwords without requiring a mix of character types or excluding the username |

### `hide-shutdown-button.txt`

Shared systems only. Ensures workstations are restarted (applying updates) rather than shut down.

| Setting | Value | Effect |
|---------|-------|--------|
| `HideShutDown` | 1 | Removes Shutdown option from Start and login screen |

### `ntlm-hardening.txt`

Forces strictest NTLM authentication level. Prevents downgrade attacks that exploit weaker LM/NTLM protocols.

| Setting | Value | Effect |
|---------|-------|--------|
| `LmCompatibilityLevel` | 5 | Send NTLMv2 only; refuse LM and NTLM |

### `defender-network-protection.txt`

Enables Windows Defender Network Protection to block connections to malicious domains and phishing sites.

| Setting | Value | Effect |
|---------|-------|--------|
| `EnableNetworkProtection` | 1 | Block connections to dangerous domains |

### `defender-pua-protection.txt`

Enables Windows Defender PUA (Potentially Unwanted Application) Protection to block adware, bundleware, and other unwanted software.

| Setting | Value | Effect |
|---------|-------|--------|
| `PUAProtection` | 1 | Block potentially unwanted applications |

### `smartscreen.txt`

Enables Windows SmartScreen and Edge PUA protection for apps, files, and downloads.

| Setting | Value | Effect |
|---------|-------|--------|
| `EnableSmartScreen` | 1 | Enable SmartScreen filter (policy) |
| `ShellSmartScreenLevel` | Warn | Warn but allow override |
| `SmartScreenEnabled` | Warn | Enable Explorer SmartScreen |
| `SmartScreenEnabled` (Edge) | 1 | Enable SmartScreen in Edge |
| `SmartScreenPuaEnabled` (Edge) | 1 | Block PUA downloads in Edge |

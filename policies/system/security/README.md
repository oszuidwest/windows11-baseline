# Security Policies

System hardening policies for malware prevention, authentication security, and attack surface reduction.

## Policies

### `disable-autorun.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `NoDriveTypeAutoRun` | 255 | Disables AutoRun/AutoPlay for all drive types |

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

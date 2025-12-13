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

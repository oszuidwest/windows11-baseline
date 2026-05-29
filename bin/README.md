# Bundled Binaries

These two binaries are tools that the deployment scripts invoke directly. They are checked into the repository (rather than downloaded at deploy time) so that deployments are reproducible and work in environments without internet access during the policy phase.

Do not replace them with downloads from third-party mirrors. If you need to update either binary, get the new version from the source listed below and update the hashes in this file in the same commit. `LGPO.exe` is published by Microsoft; `AppLockerPolicyTool.exe` is published by Aaron Margosis (its author, a former Microsoft engineer).

## Files

| File | Bytes | SHA-256 |
|------|-------|---------|
| `LGPO.exe` | 481144 | `0c97f29543418b30340c4ff5d930d31e6196dd59c2cc74b6b890fa7b90c910c7` |
| `AppLockerPolicyTool.exe` | 503264 | `163a7d3454437a43401f292ac4a48aa5c044ab54565aef4d76b39046bdf4a26d` |

## Provenance

### LGPO.exe

- Part of the Microsoft Security Compliance Toolkit.
- Source: https://www.microsoft.com/en-us/download/details.aspx?id=55319
- Used by `scripts/policies.ps1` and `scripts/_securitybaseline.ps1` to apply Local Group Policy from text or `.pol` files.

### AppLockerPolicyTool.exe

- Standalone tool for setting AppLocker policy in LGPO without needing a domain. Authored and signed by Aaron Margosis (the author of LGPO.exe; not a Microsoft Corporation binary despite the common assumption).
- Source: https://github.com/AaronMargosis/AppLockerPolicyTool
- Used by `scripts/applocker.ps1` to apply the AppLocker XML templates in `policies/applocker/`.

## Verifying

On Windows:

```powershell
Get-FileHash bin\LGPO.exe -Algorithm SHA256
Get-FileHash bin\AppLockerPolicyTool.exe -Algorithm SHA256
```

The SHA-256 values must match the table above.

On macOS/Linux:

```bash
shasum -a 256 bin/LGPO.exe bin/AppLockerPolicyTool.exe
```

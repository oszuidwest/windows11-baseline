# BitLocker Policies

Applies the Microsoft Windows 11 24H2 BitLocker hardening that is safe for editorial and production workflows.

## Policies

### `removable-media-safe.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `DenyDeviceClasses` + list value `1` | `{d48179be-ec20-11d1-b6b8-00c04fa372a7}` | Blocks IEEE 1394 / FireWire devices, matching the Microsoft BitLocker baseline device-install restriction |
| `DenyDeviceClassesRetroactive` | 1 | Applies the blocked device class policy to already-installed matching devices |
| `DeviceEnumerationPolicy` | 0 | Blocks external devices incompatible with Kernel DMA Protection until unlock |
| `UseEnhancedPin` | 1 | Allows enhanced BitLocker startup PINs |

The Microsoft BitLocker baseline also denies write access to removable drives that are not BitLocker-protected. This repository intentionally does **not** apply that setting because editorial and camera workflows need write access to SD cards and other removable media.

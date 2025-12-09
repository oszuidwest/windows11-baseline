# OneDrive Policies

Prevents automatic file sync to Microsoft cloud. Ensures files remain local for broadcast environments.

## Policies

### `disable-onedrive-sync.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `DisableFileSyncNGSC` | 1 | Prevents OneDrive from starting and syncing files |
| `DisableFileSync` | 1 | Legacy policy for Windows 8 (no effect on 10/11) |

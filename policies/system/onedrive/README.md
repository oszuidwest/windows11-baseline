# OneDrive Policies

These policies disable OneDrive file synchronization system-wide.

## Policies

### `disable-onedrive-sync.txt`

Prevents OneDrive from automatically syncing files.

| Setting | Value | Description |
|---------|-------|-------------|
| `DisableFileSyncNGSC` | 1 | Disables OneDrive Files On-Demand and file sync for users who are signed in to OneDrive |
| `DisableFileSync` | 1 | Legacy setting that disables OneDrive file sync |

## Why

- Prevents automatic upload of local files to Microsoft cloud
- Reduces bandwidth usage
- Ensures files remain local for broadcast/production environments
- Removes OneDrive integration from File Explorer

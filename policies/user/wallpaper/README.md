# Wallpaper Policy

Sets and locks the desktop wallpaper for non-admin users.

## Policies

### `set-wallpaper.txt`

Configures the desktop wallpaper.

| Setting | Value | Description |
|---------|-------|-------------|
| `Wallpaper` | `C:\Windows\deploy\wallpaper.png` | Path to wallpaper image |
| `WallpaperStyle` | 10 | Fill (scales to fill screen) |
| `TileWallpaper` | 0 | Disable tiling (required for Fill) |
| `NoChangingWallPaper` | 1 | Prevent users from changing wallpaper |

### WallpaperStyle Values

- `0` = Centered
- `2` = Stretched
- `6` = Fit
- `10` = Fill (recommended)

## Notes

The wallpaper image is downloaded during policy application from:
https://www.zuidwestupdate.nl/wp-content/uploads/2021/03/voorpagina-placeholder.png

## Why

- Provides consistent branding across shared workstations
- Prevents users from setting inappropriate backgrounds
- Professional appearance for broadcast environment

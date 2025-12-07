# Personalization Policies

User personalization and branding settings for non-admin users.

## Policies

### `set-wallpaper-branded.txt`

Sets the branded ZuidWest wallpaper for shared systems.

| Setting | Value | Description |
|---------|-------|-------------|
| `Wallpaper` | `C:\Windows\deploy\wallpaper.png` | Path to wallpaper image |
| `WallpaperStyle` | 10 | Fill (scales to fill screen) |
| `TileWallpaper` | 0 | Disable tiling (required for Fill) |
| `NoChangingWallPaper` | 1 | Prevent users from changing wallpaper |

The wallpaper image is downloaded during deployment from:
https://www.zuidwestupdate.nl/wp-content/uploads/2021/03/voorpagina-placeholder.png

### `set-wallpaper-black.txt`

Sets a solid black wallpaper for dedicated systems.

| Setting | Value | Description |
|---------|-------|-------------|
| `Wallpaper` | (empty) | No wallpaper image |
| `WallpaperStyle` | 0 | Centered (not used) |
| `Background` | `0 0 0` | RGB black color |
| `NoChangingWallPaper` | 1 | Prevent users from changing wallpaper |

### WallpaperStyle Values

- `0` = Centered
- `2` = Stretched
- `6` = Fit
- `10` = Fill (recommended for images)

## Ownership Matrix

| Ownership | Wallpaper |
|-----------|-----------|
| Shared | Branded ZuidWest image |
| Dedicated | Solid black |
| Personal | No policy (user choice) |

## Why

- **Shared**: Consistent branding, prevents inappropriate backgrounds
- **Dedicated**: Clean, distraction-free for focused work
- **Personal**: User freedom to personalize

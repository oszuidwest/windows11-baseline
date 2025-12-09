# Personalization Policies

Wallpaper settings: branded for shared systems, black for dedicated, user choice for personal.

## Policies

### `set-wallpaper-branded.txt`

Shared systems only.

| Setting | Value | Effect |
|---------|-------|--------|
| `Wallpaper` | `C:\Windows\deploy\wallpaper.png` | Sets desktop background image path |
| `WallpaperStyle` | 10 | Fills screen with image, cropping to fit |
| `TileWallpaper` | 0 | Disables tiling |
| `NoChangingWallPaper` | 1 | Prevents users from changing wallpaper |

### `set-wallpaper-black.txt`

Dedicated systems only.

| Setting | Value | Effect |
|---------|-------|--------|
| `Wallpaper` | (empty) | Clears wallpaper image |
| `Background` | `0 0 0` | Sets solid black background using RGB |
| `NoChangingWallPaper` | 1 | Prevents users from changing wallpaper |

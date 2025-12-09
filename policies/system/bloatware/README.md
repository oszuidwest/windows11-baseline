# Bloatware Policies

Disables Windows bloatware: web search, Spotlight, Widgets, and Game Bar.

## Policies

### `disable-web-in-search.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `DisableWebSearch` | 1 | Legacy setting (deprecated since 1803) |
| `AllowCloudSearch` | 0 | Prevents cloud content search for MS/Work accounts |
| `DisableSearchBoxSuggestions` | 1 | Removes web results and suggestions from Start menu |

### `disable-spotlight.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `DisableWindowsSpotlightFeatures` | 1 | Disables lock screen images, tips, and suggestions |

### `disable-widgets.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `AllowNewsAndInterests` | 0 | Disables Widgets entirely (taskbar + lock screen) |
| `DisableWidgetsOnLockScreen` | 1 | Removes widgets from lock screen only |

### `disable-game-bar.txt`

| Setting | Value | Effect |
|---------|-------|--------|
| `AllowGameDVR` | 0 | Disables Game Bar and game recording/broadcasting |
| `AppCaptureEnabled` | 0 | Disables screen capture functionality |

Game Bar is not installed on LTSC, but these settings suppress popup messages.

Copilot is blocked via AppLocker since the GPO is deprecated in Windows 11 24H2.

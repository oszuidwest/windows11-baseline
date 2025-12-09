# Bloatware Policies

These policies disable Windows bloatware features system-wide.

## Policies

### `disable-web-in-search.txt`

Disables web search in Windows Search.

| Setting | Value | Description |
|---------|-------|-------------|
| `DisableWebSearch` | 1 | Disable web search in Start menu |
| `AllowCloudSearch` | 0 | Disable cloud/Bing search integration |
| `DisableSearchBoxSuggestions` | 1 | Disable search suggestions from the web |

### `disable-spotlight.txt`

Disables Windows Spotlight features.

| Setting | Value | Description |
|---------|-------|-------------|
| `DisableWindowsSpotlightFeatures` | 1 | Disable tips, suggestions, and spotlight content |

### `disable-widgets.txt`

Disables Windows 11 Widgets panel.

| Setting | Value | Description |
|---------|-------|-------------|
| `AllowNewsAndInterests` | 0 | Disable Widgets panel |
| `DisableWidgetsOnLockScreen` | 1 | Disable widgets on lock screen |

### `disable-game-bar.txt`

Disables Xbox Game Bar and DVR functionality.

| Setting | Value | Description |
|---------|-------|-------------|
| `AllowGameDVR` | 0 | Disable Game DVR/recording |
| `AppCaptureEnabled` | 0 | Disable app capture |

Note: Game Bar is not installed on Windows 11 LTSC, but these settings suppress "broken Game Bar" popup messages.

## Why

- Makes Start menu search fast and local-only
- Prevents accidental web searches when looking for local files/apps
- Removes Windows tips, suggestions, and Widgets
- Suppresses Game Bar popups on LTSC
- Reduces bandwidth usage and improves privacy

Note: Copilot is blocked via AppLocker (see `policies/applocker/`) since the GPO is deprecated in Windows 11 24H2.

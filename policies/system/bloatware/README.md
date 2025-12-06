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

## Why

- Makes Start menu search fast and local-only
- Prevents accidental web searches when looking for local files/apps
- Reduces bandwidth usage and improves privacy

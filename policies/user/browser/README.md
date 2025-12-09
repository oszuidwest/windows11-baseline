# Browser Policies

Privacy and security settings for Microsoft Edge.

## Policies

### `edge-profile.txt`

Session and profile management for shared systems only.

| Setting | Value | Description |
|---------|-------|-------------|
| `ForceEphemeralProfiles` | 1 | Temporary profile, deleted on exit |
| `SyncDisabled` | 1 | Disable profile sync |
| `BrowserSignin` | 0 | Disable browser sign-in |
| `HideFirstRunExperience` | 1 | Skip first-run wizard |
| `BrowserAddProfileEnabled` | 0 | Block creating new profiles |
| `BrowserGuestModeEnabled` | 0 | Disable guest mode |

### `edge-privacy.txt`

Tracking prevention and security settings. Applied to all systems.

| Setting | Value | Description |
|---------|-------|-------------|
| `TrackingPrevention` | 2 | Strict tracking prevention |
| `ConfigureDoNotTrack` | 1 | Send Do Not Track header |
| `PersonalizationReportingEnabled` | 0 | No usage analytics |
| `SitePerProcess` | 1 | Site isolation enabled |
| `TyposquattingCheckerEnabled` | 1 | Phishing protection |
| `BingSafeSearchMode` | 1 | Moderate safe search |
| `UserFeedbackAllowed` | 0 | No feedback prompts |
| `DiagnosticData` | 0 | Minimal diagnostic data |

### `edge-autofill.txt`

Disable autofill and data import. Shared systems only.

| Setting | Value | Description |
|---------|-------|-------------|
| `PasswordManagerEnabled` | 0 | No password saving |
| `AutofillCreditCardEnabled` | 0 | No credit card autofill |
| `AutofillAddressEnabled` | 0 | No address autofill |
| `Import*` | 0 | Block all data import |

### `edge-ui.txt`

Remove bloatware and distractions from Edge UI. Applied to all systems.

| Setting | Value | Description |
|---------|-------|-------------|
| `DefaultNotificationsSetting` | 2 | Block notifications |
| `ShowRecommendationsEnabled` | 0 | No recommendations |
| `SpotlightExperiencesAndRecommendationsEnabled` | 0 | No spotlight tips |
| `ShowMicrosoftRewards` | 0 | Hide rewards |
| `EdgeShoppingAssistantEnabled` | 0 | No shopping assistant |
| `EdgeWalletCheckoutEnabled` | 0 | No wallet checkout |
| `WalletDonationEnabled` | 0 | No wallet donations |
| `MicrosoftOfficeMenuEnabled` | 0 | No Office menu |
| `OutlookHubMenuEnabled` | 0 | No Outlook hub |
| `AllowGamesMenu` | 0 | No games menu |
| `NewTabPageContentEnabled` | 0 | Clean new tab page |
| `NewTabPageQuickLinksEnabled` | 0 | No quick links on new tab |
| `HubsSidebarEnabled` | 0 | No Copilot/Bing sidebar |
| `Microsoft365CopilotChatIconEnabled` | 0 | No Copilot icon in toolbar |
| `HomepageLocation` | https://www.zuidwestupdate.nl/ | Set homepage |
| `HomepageIsNewTabPage` | 0 | Use custom homepage |
| `RestoreOnStartup` | 4 | Open specific URLs on startup |
| `RestoreOnStartupURLs` | https://www.zuidwestupdate.nl/ | Open on startup |

### `edge-developer-tools.txt`

Disable developer tools. Shared systems only.

| Setting | Value | Description |
|---------|-------|-------------|
| `DeveloperToolsAvailability` | 2 | Completely disable F12 developer tools |

### `edge-extensions.txt`

Block extension installations. Shared systems only.

| Setting | Value | Description |
|---------|-------|-------------|
| `ExtensionInstallBlocklist` | * | Block all extension installs |

## Why

- **Ephemeral profiles**: No user data persists between sessions
- **No autofill**: Prevents accidental storage of sensitive data
- **Clean UI**: Removes distractions and promotional content
- **Privacy**: Strict tracking prevention, no analytics
- **Security**: Site isolation, phishing protection

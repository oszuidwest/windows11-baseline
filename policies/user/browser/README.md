# Browser Policies

Microsoft Edge: ephemeral profiles, strict privacy, no autofill, clean UI, no extensions.

## Policies

### `edge-profile.txt`

Shared systems only. Profiles are deleted on exit.

| Setting | Value | Effect |
|---------|-------|--------|
| `ForceEphemeralProfiles` | 1 | Profiles deleted when browser session ends |
| `SyncDisabled` | 1 | Disables data synchronization |
| `BrowserSignin` | 0 | Disables browser sign-in completely |
| `HideFirstRunExperience` | 1 | Hides first-run experience and splash screen |
| `BrowserAddProfileEnabled` | 0 | Prevents users from creating new profiles |
| `BrowserGuestModeEnabled` | 0 | Disables guest profile browsing mode |

### `edge-privacy.txt`

All systems.

| Setting | Value | Effect |
|---------|-------|--------|
| `TrackingPrevention` | 2 | Balanced tracking prevention blocks harmful trackers |
| `ConfigureDoNotTrack` | 1 | Sends Do Not Track requests to websites |
| `PersonalizationReportingEnabled` | 0 | Prevents browsing history collection for personalization |
| `SitePerProcess` | 1 | Isolates each site in separate process |
| `TyposquattingCheckerEnabled` | 1 | Enables website typo protection warnings |
| `ForceBingSafeSearch` | 1 | Enforces moderate SafeSearch on Bing |
| `UserFeedbackAllowed` | 0 | Disables Edge Feedback feature |
| `DiagnosticData` | 0 | Disables required and optional diagnostic data |

### `edge-autofill.txt`

Shared systems only.

| Setting | Value | Effect |
|---------|-------|--------|
| `PasswordManagerEnabled` | 0 | Prevents saving new passwords |
| `AutofillCreditCardEnabled` | 0 | Blocks saving and filling credit cards |
| `AutofillAddressEnabled` | 0 | Blocks saving and filling addresses |
| `ImportAutofillFormData` | 0 | Prevents importing browser data at first run |
| `ImportBrowserSettings` | 0 | Prevents importing browser data at first run |
| `ImportCookies` | 0 | Prevents importing browser data at first run |
| `ImportExtensions` | 0 | Prevents importing browser data at first run |
| `ImportFavorites` | 0 | Prevents importing browser data at first run |
| `ImportHistory` | 0 | Prevents importing browser data at first run |
| `ImportHomepage` | 0 | Prevents importing browser data at first run |
| `ImportPaymentInfo` | 0 | Prevents importing browser data at first run |
| `ImportSavedPasswords` | 0 | Prevents importing browser data at first run |
| `ImportSearchEngine` | 0 | Prevents importing browser data at first run |
| `ImportShortcuts` | 0 | Prevents importing browser data at first run |
| `ImportStartupPageSettings` | 0 | Prevents importing browser data at first run |
| `ImportOpenTabs` | 0 | Prevents importing browser data at first run |

### `edge-ui.txt`

All systems. Removes bloatware from Edge UI.

| Setting | Value | Effect |
|---------|-------|--------|
| `DefaultNotificationsSetting` | 2 | Blocks all website desktop notifications |
| `ShowRecommendationsEnabled` | 0 | Disables browser feature recommendations |
| `SpotlightExperiencesAndRecommendationsEnabled` | 0 | Turns off customized backgrounds and tips |
| `ShowMicrosoftRewards` | 0 | Hides Microsoft Rewards from profile |
| `EdgeShoppingAssistantEnabled` | 0 | Disables price comparison and coupons |
| `EdgeWalletCheckoutEnabled` | 0 | Disables Wallet checkout feature |
| `WalletDonationEnabled` | 0 | Disables Wallet donation feature |
| `NewTabPageContentEnabled` | 0 | Hides Microsoft content on new tab page |
| `NewTabPageQuickLinksEnabled` | 0 | Hides quick links on new tab page |
| `HubsSidebarEnabled` | 0 | Completely hides Edge sidebar |
| `Microsoft365CopilotChatIconEnabled` | 0 | Hides Copilot Chat icon from toolbar |
| `HomepageLocation` | https://www.zuidwestupdate.nl/ | Sets homepage URL |
| `HomepageIsNewTabPage` | 0 | Uses custom homepage instead of new tab |
| `RestoreOnStartup` | 4 | Opens specific URLs on startup |
| `RestoreOnStartupURLs` | https://www.zuidwestupdate.nl/ | URL to open on startup |

### `edge-developer-tools.txt`

Shared systems only.

| Setting | Value | Effect |
|---------|-------|--------|
| `DeveloperToolsAvailability` | 2 | Blocks F12 developer tools and view source |

### `edge-extensions.txt`

Shared systems only.

| Setting | Value | Effect |
|---------|-------|--------|
| `ExtensionInstallBlocklist` | * | Blocks all extensions unless explicitly allowed |

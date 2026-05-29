# Browser Policies

Microsoft Edge and Google Chrome: ephemeral profiles for shared systems, strict privacy, no autofill, clean UI, no extensions. Browser sign-in is disabled except on personal systems, where only ZuidWest work/school accounts are allowed. Chrome Google service sign-in is limited to ZuidWest Google account domains on all systems.

## Policies

### `edge-profile.txt`

Shared systems only. Profiles are deleted on exit.

| Setting | Value | Effect |
|---------|-------|--------|
| `ForceEphemeralProfiles` | 1 | Profiles deleted when browser session ends |
| `SyncDisabled` | 1 | Disables data synchronization |
| `HideFirstRunExperience` | 1 | Hides first-run experience and splash screen |
| `BrowserAddProfileEnabled` | 0 | Prevents users from creating new profiles |
| `BrowserGuestModeEnabled` | 0 | Disables guest profile browsing mode |

### `edge-sign-in.txt`

Personal systems only. Edge sign-in is allowed only for ZuidWest work/school
account UPNs in the `zuidwestupdate.nl`, `zuidwesttv.nl`, and `zuidwestfm.nl`
domains.

| Setting | Value | Effect |
|---------|-------|--------|
| `BrowserSignin` | 1 | Allows browser sign-in for accounts matching the allowed pattern |
| `RestrictSigninToPattern` | `(?i)^[^@]+@(zuidwestupdate\.nl\|zuidwesttv\.nl\|zuidwestfm\.nl)$` | Blocks personal/non-ZuidWest accounts from Edge sign-in |
| `MSAWebSiteSSOUsingThisProfileAllowed` | 0 | Blocks personal Microsoft account SSO in non-MSA profiles |

### `edge-disable-sign-in.txt`

Shared and dedicated systems only.

| Setting | Value | Effect |
|---------|-------|--------|
| `BrowserSignin` | 0 | Disables Edge browser sign-in completely |

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

### `chrome-profile.txt`

Shared systems only. Profiles are deleted on exit and browsing history is not saved.

| Setting | Value | Effect |
|---------|-------|--------|
| `ForceEphemeralProfiles` | 1 | Profiles deleted when browser session ends |
| `SyncDisabled` | 1 | Disables data synchronization |
| `BrowserGuestModeEnabled` | 0 | Disables guest profile browsing mode |
| `ProfilePickerOnStartupAvailability` | 1 | Disables the profile picker at startup |
| `SavingBrowserHistoryDisabled` | 1 | Prevents saving browsing history |

### `chrome-sign-in.txt`

Personal systems only. Chrome sign-in is allowed only for ZuidWest Google
account addresses in the `zuidwestupdate.nl`, `zuidwesttv.nl`, and `zuidwestfm.nl`
domains.

| Setting | Value | Effect |
|---------|-------|--------|
| `BrowserSignin` | 1 | Allows Chrome sign-in for accounts matching the allowed pattern |
| `RestrictSigninToPattern` | `(?i)^[^@]+@(zuidwestupdate\.nl\|zuidwesttv\.nl\|zuidwestfm\.nl)$` | Blocks personal/non-ZuidWest Google accounts from Chrome sign-in |

### `chrome-disable-sign-in.txt`

Shared and dedicated systems only.

| Setting | Value | Effect |
|---------|-------|--------|
| `BrowserSignin` | 0 | Disables Chrome browser sign-in completely |

### `chrome-google-accounts.txt`

All systems. Blocks Chrome users from signing in to Google services with accounts outside the ZuidWest Google domains.

| Setting | Value | Effect |
|---------|-------|--------|
| `AllowedDomainsForApps` | `zuidwestupdate.nl,zuidwesttv.nl,zuidwestfm.nl` | Allows Google service sign-in only for these domains |

### `chrome-privacy.txt`

All systems.

| Setting | Value | Effect |
|---------|-------|--------|
| `UserFeedbackAllowed` | 0 | Disables Chrome feedback reports |
| `UrlKeyedAnonymizedDataCollectionEnabled` | 0 | Disables URL-keyed anonymized data collection |
| `SearchSuggestEnabled` | 0 | Disables search and URL suggestions |
| `SafeBrowsingProtectionLevel` | 1 | Enforces Standard Safe Browsing |
| `DisableSafeBrowsingProceedAnyway` | 1 | Blocks bypassing Safe Browsing warnings |
| `SafeBrowsingExtendedReportingEnabled` | 0 | Disables extended Safe Browsing reporting |
| `SafeBrowsingSurveysEnabled` | 0 | Disables Safe Browsing surveys |
| `SitePerProcess` | 1 | Isolates each site in a separate process |
| `HttpsUpgradesEnabled` | 1 | Upgrades navigations to HTTPS when possible |
| `PrivacySandboxAdMeasurementEnabled` | 0 | Disables Privacy Sandbox ad measurement |
| `PrivacySandboxAdTopicsEnabled` | 0 | Disables Privacy Sandbox ad topics |
| `PrivacySandboxSiteEnabledAdsEnabled` | 0 | Disables site-suggested ads |
| `PrivacySandboxPromptEnabled` | 0 | Suppresses Privacy Sandbox prompts |

### `chrome-autofill.txt`

Shared systems only.

| Setting | Value | Effect |
|---------|-------|--------|
| `PasswordManagerEnabled` | 0 | Prevents saving new passwords |
| `PasswordManagerPasskeysEnabled` | 0 | Prevents Chrome passkey storage |
| `PasswordSharingEnabled` | 0 | Disables password sharing |
| `AutofillCreditCardEnabled` | 0 | Blocks saving and filling credit cards |
| `AutofillAddressEnabled` | 0 | Blocks saving and filling addresses |
| `PaymentMethodQueryEnabled` | 0 | Blocks sites from checking stored payment methods |
| `ImportAutofillFormData` | 0 | Prevents importing browser form data |
| `ImportBookmarks` | 0 | Prevents importing bookmarks |
| `ImportHistory` | 0 | Prevents importing browsing history |
| `ImportHomepage` | 0 | Prevents importing homepage settings |
| `ImportSavedPasswords` | 0 | Prevents importing saved passwords |
| `ImportSearchEngine` | 0 | Prevents importing search engine settings |

### `chrome-ui.txt`

All systems. Removes noisy Chrome UI elements.

| Setting | Value | Effect |
|---------|-------|--------|
| `DefaultNotificationsSetting` | 2 | Blocks all website desktop notifications |
| `DefaultPopupsSetting` | 2 | Blocks website popups by default |
| `PromotionsEnabled` | 0 | Disables Chrome promotions |
| `PromotionalTabsEnabled` | 0 | Disables promotional tabs |
| `ShoppingListEnabled` | 0 | Disables shopping list features |
| `NTPMiddleSlotAnnouncementVisible` | 0 | Hides new tab announcements |
| `NTPCardsVisible` | 0 | Hides new tab cards |
| `NTPCustomBackgroundEnabled` | 0 | Disables custom new tab backgrounds |
| `GoogleSearchSidePanelEnabled` | 0 | Disables Google Search side panel |
| `LensOverlaySettings` | 1 | Disables Google Lens overlay |
| `ShowFullUrlsInAddressBar` | 1 | Shows full URLs in the address bar |

### `chrome-developer-tools.txt`

Shared systems only.

| Setting | Value | Effect |
|---------|-------|--------|
| `DeveloperToolsAvailability` | 2 | Blocks F12 developer tools and view source |

### `chrome-extensions.txt`

All systems.

| Setting | Value | Effect |
|---------|-------|--------|
| `ExtensionInstallBlocklist` | * | Blocks all extensions unless explicitly allowed |

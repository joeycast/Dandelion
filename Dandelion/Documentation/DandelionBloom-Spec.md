# Dandelion Bloom - Premium Feature Specification

## Overview

**Dandelion Bloom** is the premium tier for Dandelion, offering enhanced personalization and deeper insights. Purchasing Bloom supports ongoing development. The name evokes growth and flourishing—fitting the app's botanical theme.

### Key Decisions
- **Name:** Dandelion Bloom
- **Platforms:** iOS, iPadOS, macOS (Universal Purchase)
- **macOS Access:** Bloom required to use the macOS app (gate on launch)
- **Price:** $4.99 one-time purchase
- **Insights UI:** Insights tab in Release History sheet (replaces Stats tab)
- **Custom Prompts:** Fully premium (0 free)
- **Export:** On-device only (share sheet / file export, no web service)
- **Alternative Styles:** Style-specific animation profiles; watercolor/pencil can use reduced or unique motion

---

## Feature Set

### Free Tier (Current)
- Core writing and release experience
- Basic stats (total releases, words, streaks)
- 15 curated prompts with rotation
- No custom prompts
- Procedural dandelion animation
- Dark theme

### Dandelion Bloom (Premium)

| Feature | Description |
|---------|-------------|
| **Enhanced Statistics** | Deeper insights into your release practice |
| **Export History** | Download your journey as CSV or shareable summary |
| **Custom Prompts** | Create, edit, and manage unlimited custom prompts |
| **Color Palettes** | Dawn, Twilight, Forest themes |
| **Dandelion Styles** | Watercolor, Pencil Art (style-specific animation profiles) |
| **Alternate Icons** | Match your chosen style/theme |
| **Ambient Sounds** | Wind, Rain, Fire during writing |

---

## Detailed Feature Specifications

### 1. Enhanced Statistics

**Current stats available (free):**
- Total releases (all-time and per year)
- Total words released
- Current streak
- Longest streak

**New premium stats** (derived from timestamp + wordCount, local timezone):

| Stat | Description |
|------|-------------|
| Journey Start | Date of your first release |
| Days on Journey | Calendar days since first release |
| Active Days | Total unique days with releases |
| Releases per Week | Rolling 7-day total and 4-week average |
| 30-Day Trend | Last 30 days vs previous 30 days (count and percent) |
| Average Words/Release | Mean words per release |
| Median Words/Release | Median words per release |
| Longest Release | Most words in a single release |
| Shortest Release | Fewest words in a single release |
| Words per Active Day | Total words divided by active days |
| Most Active Day | Weekday with highest release count |
| Most Active Time | Time-of-day bucket with most releases (Morning/Afternoon/Evening/Night) |
| Monthly Chart | Releases and words per month (last 12 months) |

Time-of-day buckets (local): Morning 5:00-11:59, Afternoon 12:00-16:59, Evening 17:00-21:59, Night 22:00-4:59.

**UI Location:** Insights tab in the Release History sheet (replaces the Stats tab)

**Insights layout (default):**
- Header summary row: Total releases, total words, current streak, longest streak.
- Section: "Last 30 Days" with releases, words, and trend vs previous 30 days.
- Section: Charts (monthly releases + monthly words, last 12 months).
- Section: Activity (most active day, most active time, releases per week).

**Date range:** Default to last 12 months for charts; last 30 days for trends. All-time aggregates remain in the header.

**Empty states:**
- No releases yet: show a gentle prompt to write and a placeholder illustration.
- Low data: show partial stats with "Not enough data yet" labels where needed.

### 2. Export Release History

**Formats (on-device only):**
- **CSV** — On-device file export for spreadsheet analysis
- **Summary Text** — Shareable prose summary generated locally

**Example summary output:**
```
My Dandelion Journey

Started: March 15, 2024
Total Releases: 127
Words Released: 24,891
Longest Streak: 14 days

"127 moments of letting go."
```

**CSV columns:**
- `timestamp_iso8601` (local time with offset)
- `local_date` (YYYY-MM-DD)
- `local_time` (HH:MM)
- `word_count`

**Notes:** Export includes release metadata only (no writing content).

**UI:** Export button in the Release History sheet with format picker. Use ShareLink / file exporter; no email or web service.

### 3. Custom Prompts Management

**Capabilities (Premium only):**
- Create unlimited custom prompts
- Edit existing custom prompts
- Delete custom prompts
- Toggle prompts on/off (soft disable)
- View default prompts (read-only, always available)

**Free tier:** No custom prompts. Any create/edit action triggers the Bloom paywall.

**Data Model:**
```swift
@Model
final class CustomPrompt {
    var id: UUID
    var text: String
    var createdAt: Date
    var isActive: Bool
}
```

**UI Location:** Settings → Prompts

### 4. Color Palettes

| Palette | Background | Primary | Accent | Mood |
|---------|------------|---------|--------|------|
| **Dark** (free) | Black | Pale Yellow | Gold | Night/Stars |
| **Dawn** | Soft peach | Warm white | Rose gold | Morning calm |
| **Twilight** | Deep indigo | Lavender | Silver | Evening peace |
| **Forest** | Dark green | Sage | Moss | Nature grounded |

**Implementation:** Extend Theme.swift with ThemeManager that switches color palettes. All UI elements already use Theme colors, so switching is straightforward.

**UI Location:** Settings → Appearance

### 5. Alternative Dandelion Illustrations

**Current:** Procedurally-generated via Canvas (140 seeds, wind physics)

**New Styles (style-specific animation profiles):**

| Style | Description |
|-------|-------------|
| **Procedural** (free) | Current detailed animation |
| **Watercolor** | Soft gradient washes, blurred edges, dreamy bloom effect |
| **Pencil Art** | Hand-drawn sketch aesthetic, textured strokes |

Each style defines its own animation profile:
- **Procedural**: current full seed physics and regrowth
- **Watercolor**: reduced seed count, slower drift, soft bloom pulses
- **Pencil Art**: subtle sway and sketch-line reveal with light seed drift on release

The release interaction should still clearly convey "letting go" in every style.

**Implementation approach:** Add `style` parameter to `DandelionBloomView` with different rendering paths in Canvas. Each style owns its animation profile and visual treatments (stroke styles, gradients, opacity effects) to achieve the artistic look.

**UI Location:** Settings → Appearance → Dandelion Style

### 6. Alternate App Icons

Icons to match themes and styles:
- Default (current dark theme)
- Watercolor dandelion
- Minimalist line art
- Dawn palette variant
- Twilight palette variant
- Forest palette variant

**Implementation:** Platform-specific alternate icon APIs. iOS/iPadOS: `UIApplication.shared.setAlternateIconName()`. macOS: if alternate icons are not supported for the target, hide the setting and keep the default icon.

**UI Location:** Settings → App Icon

### 7. Ambient Sounds

| Sound | Description |
|-------|-------------|
| **Wind** | Gentle breeze, rustling |
| **Rain** | Soft rainfall, cozy |
| **Fire** | Crackling fireplace, warm |

**Behavior:**
- Plays during writing state
- Fades out gracefully during release animation
- Respects system volume and silent mode
- Loops seamlessly
- Volume slider in settings

**Implementation:** New `AmbientSoundService` using AVAudioPlayer with bundled audio files

**UI Location:** Settings → Sounds (with quick toggle in writing view)

## Premium Gating & CTA Screens

### Gating Philosophy
- Never interrupt the core writing experience
- Show premium features as "locked" with gentle upgrade prompts
- Always allow dismissal—no forced paywalls

### Paywall Screen Design

**Layout:**
1. Animated dandelion illustration (gentle, not flashy)
2. "Dandelion Bloom" title
3. Tagline: "Grow your practice"
4. Feature highlights with elegant icons
5. Price + Purchase button
6. "Restore Purchases" link
7. Close button (always visible)

**Tone:** Calm, inviting, not aggressive. Matches the app's meditative feel.

### Gating Touchpoints

| Location | Behavior |
|----------|----------|
| Custom Prompts | "Manage Prompts" shows upgrade prompt (fully premium) |
| Color Palettes | Locked palettes show preview + upgrade |
| Dandelion Styles | Locked styles show preview + upgrade |
| Ambient Sounds | Sound toggles show upgrade prompt |
| Enhanced Stats | Insights tab shows locked preview + "Unlock insights" |
| Export | Export button shows upgrade prompt in Insights |
| App Icons | Locked icons show upgrade prompt |
| macOS app launch | Bloom gate blocks access until purchase/restore |

---

### macOS Access Gate

macOS is premium-only: the app launches into a Bloom gate when the user is not entitled.

**Behavior:**
- On launch, check Bloom entitlement and show the paywall if not purchased.
- Block access to writing, history, settings, and themes until unlocked.
- Provide "Restore Purchases" and a short explanation that macOS access requires Bloom.
- Cache entitlement locally; re-validate on launch and when returning to foreground.
- If StoreKit is unavailable, show a retry state; do not unlock without entitlement.
- Offline behavior: if a cached entitlement exists, allow access while offline; if not, require purchase/restore when back online.

**Paywall copy (macOS launch gate):**
- **Title:** Dandelion Bloom Required
- **Subtitle:** Unlock the full Dandelion experience on Mac.
- **Body:** Bloom is a one-time purchase that brings Insights, custom prompts, themes, and ambient sounds to all your devices.
- **Primary CTA:** Unlock Bloom — $4.99
- **Secondary CTA:** Restore Purchases
- **Footer:** Universal Purchase — use Bloom on iPhone, iPad, and Mac.

**App Store listing notes (macOS):**
- **Subtitle/Promotional Text (short):** Bloom required on Mac.
- **Description (opening line):** Dandelion for Mac is a premium experience unlocked with the Bloom one-time purchase (Universal Purchase).
- **What’s New/Release Notes (if gating ships later):** Mac access now requires Bloom; purchase once, use on all devices.

## Pricing Strategy

### Recommendation: One-Time Purchase — $4.99

Use Universal Purchase so a single non-consumable IAP unlocks Bloom on iOS, iPadOS, and macOS.

**Rationale:**

1. **Philosophy alignment** — Dandelion is about "letting go." A subscription creates ongoing obligations that contradict this ethos. One-time purchase = pay once, enjoy forever.

2. **User psychology** — Journaling app subscriptions often face:
   - High churn (users forget why they're paying)
   - Negative reviews ("why subscribe for notes?")
   - Guilt when not using frequently

3. **Market position** — Positioned as generous and honest:
   - Day One: ~$3-5/month subscription
   - Bear Notes: One-time $15
   - Dandelion at $4.99 one-time feels fair

4. **Simplicity** — No subscription management, no "premium expired" states, no complex entitlement logic

### Alternative Considered: Subscription

If choosing subscription:
- $1.99/month or $9.99/year
- Offers recurring revenue
- But contradicts app philosophy and adds complexity

---

## Technical Architecture

### New Services

```
Dandelion/Core/
├── Premium/
│   └── PremiumManager.swift      # StoreKit 2, entitlements
├── Audio/
│   └── AmbientSoundService.swift # Audio playback
├── Design/
│   └── ThemeManager.swift        # Color palette switching
└── Data/
    ├── Models/
    │   ├── CustomPrompt.swift    # SwiftData model
    │   └── UserPreferences.swift # Theme/sound prefs
    └── Services/
        └── ExportService.swift   # On-device CSV/text export
```

### Entitlement Strategy

- **Source of truth:** StoreKit 2 entitlement for `com.dandelion.bloom.premium`.
- **Cached state:** Persist a local boolean for quick gating and offline access.
- **Refresh points:** App launch, app foreground, and after purchase/restore.
- **macOS gate:** If not entitled and no cached unlock, block access and show the Bloom paywall.

### StoreKit 2 Products

| Product ID | Type | Price |
|------------|------|-------|
| `com.dandelion.bloom.premium` | Non-Consumable | $4.99 |

Configure the IAP for Universal Purchase so the entitlement is shared across iOS, iPadOS, and macOS.

**StoreKit configuration (development/testing):**
- Add a StoreKit Configuration file to the project with `com.dandelion.bloom.premium`.
- Ensure bundle-specific product IDs are aligned across iOS/iPadOS/macOS targets for Universal Purchase.
- Use StoreKit Testing in Xcode for purchase, restore, and offline flows.

### Data Model Updates

Add to SwiftData schema in `DandelionApp.swift`:
- `CustomPrompt` — User-created prompts
- `UserPreferences` — Selected theme, dandelion style, ambient sound

### Key Files to Modify

| File | Changes |
|------|---------|
| `DandelionApp.swift` | Add new models to schema |
| `ContentView.swift` | Gate macOS entry when Bloom is not unlocked |
| `Theme.swift` | Add color palettes, integrate with ThemeManager |
| `DandelionBloomView.swift` | Add style parameter, alternative renderers |
| `ReleaseHistoryService.swift` | Add enhanced stats methods |
| `ReleaseHistoryView.swift` | Add Insights tab and export UI |
| `SettingsView.swift` | Expand with new sections |
| `Prompt.swift` | Integrate CustomPrompt with PromptsManager |

---

## Development Plan

### Branching Strategy

```
main
 │
 └── feature/dandelion-bloom (integration branch)
      │
      ├── premium/infrastructure
      │   └── PremiumManager, StoreKit 2, gating system
      │
      ├── premium/enhanced-stats
      │   └── Stats calculations, stats UI, export
      │
      ├── premium/custom-prompts
      │   └── CustomPrompt model, management UI
      │
      ├── premium/theming
      │   └── ThemeManager, palettes, picker UI
      │
      ├── premium/dandelion-styles
      │   └── Alternative renderers, style picker
      │
      ├── premium/ambient-sounds
      │   └── AmbientSoundService, audio assets, UI
      │
      ├── premium/alternate-icons
      │   └── Icon assets, icon picker
```

### Implementation Order

1. **Infrastructure** — PremiumManager + StoreKit 2 + basic paywall (foundation for everything)
2. **Enhanced Stats + Export** — High value, extends existing feature
3. **Custom Prompts** — High user value, clear implementation
4. **Theming** — Visual impact, ThemeManager needed for other features
5. **Ambient Sounds** — Standalone audio system
6. **Dandelion Styles** — Artistic work, can be parallelized
7. **Alternate Icons** — Requires artwork, lower priority

### Testing Strategy

- Unit tests for PremiumManager, ThemeManager, AmbientSoundService
- Unit tests for enhanced stats calculations
- StoreKit testing configuration for purchase flow
- UI tests for paywall and settings flows
- UI tests for macOS gate (paywall on launch)
- Manual testing across all color palettes and styles

### Accessibility

- Support Dynamic Type across settings, paywall, and Insights.
- VoiceOver labels for paywall CTAs, charts, toggles, and export actions.
- Sufficient contrast for all palettes; validate text-on-background for each theme.

### Localization

- English only for this release. Keep new strings centralized for future localization.

### Data Migration

- No migration planned (app not live). Adding new SwiftData models is expected to be clean.

---

## Verification Plan

After implementation, verify:

1. **Purchase flow** — Can purchase premium, entitlement persists
2. **Restore purchases** — Works across app reinstall
3. **Feature gating** — Each premium feature properly locked/unlocked
4. **macOS gate** — App access blocked until Bloom purchase/restore
5. **Custom prompts** — CRUD operations work, sync via CloudKit
6. **Themes** — All UI elements respond to palette changes
7. **Dandelion styles** — All styles render at 60fps, animate correctly
8. **Ambient sounds** — Play, loop, fade, respect system settings
9. **Export** — CSV and summary generate correctly
10. **Stats** — All calculations accurate against test data
11. **Icons** — All alternate icons switch correctly

---

## Resolved Decisions

| Decision | Choice |
|----------|--------|
| Premium name | Dandelion Bloom |
| Platforms | iOS, iPadOS, macOS |
| macOS access | Bloom required to use the macOS app |
| Pricing model | $4.99 one-time purchase |
| Free custom prompts | 0 (fully premium feature) |
| Insights UI | Release History sheet, Insights tab |
| Export delivery | On-device only (share sheet / file export) |
| Alternative styles | Style-specific animation profiles (not all full physics) |

## Remaining Considerations

- **Sound assets** — Will need royalty-free ambient audio (wind, rain, fire)
- **Artwork** — Alternative icon designs needed for each style/theme

---

## iCloud Sync Requirements

All user data must persist across app reinstalls and sync across devices via CloudKit.

### Data That Must Sync

| Data | Storage | Sync |
|------|---------|------|
| Custom Prompts | SwiftData | CloudKit (automatic) |
| User Preferences | SwiftData | CloudKit (automatic) |
| Release History | SwiftData | CloudKit (already implemented) |
| Premium Entitlements | App Store | Automatic via StoreKit |

### Implementation

The app already uses SwiftData with CloudKit enabled (see `DandelionApp.swift`):

```swift
let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    cloudKitDatabase: .automatic  // ← Enables iCloud sync
)
```

Adding `CustomPrompt` and `UserPreferences` to the schema automatically enables sync.

### Restore Flow
1. User reinstalls app or gets new device
2. SwiftData + CloudKit automatically syncs custom prompts and preferences
3. User taps "Restore Purchases" to restore Dandelion Bloom entitlement
4. All premium features and customizations are restored

---

## Visual Consistency: Dandelion Styles × Color Palettes

Each dandelion style must look beautiful against every color palette.

### Color Palette Specifications

| Palette | Background | Seed Color | Stem Color | Accent |
|---------|------------|------------|------------|--------|
| **Dark** | Black (#000000) | Off-white (#F8F3E6) | Sage green (#A4BD5C) | Gold (#D9C073) |
| **Dawn** | Soft peach (#FEF0E8) | Warm brown (#6B5B4F) | Olive (#8B9A6B) | Rose gold (#C9A86C) |
| **Twilight** | Deep indigo (#1A1A3E) | Lavender (#E0D8F0) | Muted teal (#5B7B7A) | Silver (#B8C4D0) |
| **Forest** | Dark green (#1C2B1C) | Cream (#F5F0E1) | Moss (#6B8E5B) | Amber (#C4A35A) |

### Style × Palette Matrix

| | Dark | Dawn | Twilight | Forest |
|---|---|---|---|---|
| **Procedural** | Current look | Warm, earthy seeds | Ethereal, glowing | Natural, organic |
| **Watercolor** | Soft glows on black | Warm washes | Cool dreamy washes | Earthy, muted |
| **Pencil Art** | White sketch on black | Brown sketch on peach | Silver sketch on indigo | Sepia on green |

### Visual Tuning Required

For each style, tune these parameters per palette:
- Seed opacity and color
- Filament stroke width and color
- Stem gradient colors
- Core/center glow colors
- Shadow/depth effects

### Testing Visual Consistency

Create a debug view that displays all 9 combinations (3 styles × 3 premium palettes + free dark) for visual QA.

---

## Test Specifications

### Unit Tests

**File:** `DandelionTests/PremiumManagerTests.swift`

```swift
class PremiumManagerTests: XCTestCase {
    // Entitlement state
    func testInitialStateIsNotPremium()
    func testPremiumStateAfterPurchase()
    func testFeatureGatingWhenNotPremium()
    func testFeatureGatingWhenPremium()

    // Product loading
    func testProductsLoad()
    func testPremiumProductExists()
}
```

**File:** `DandelionTests/ThemeManagerTests.swift`

```swift
class ThemeManagerTests: XCTestCase {
    // Palette switching
    func testDefaultPaletteIsDark()
    func testCanSwitchPalette()
    func testPaletteColorsAreDistinct()

    // Premium gating
    func testDarkPaletteIsFree()
    func testOtherPalettesArePremium()
}
```

**File:** `DandelionTests/CustomPromptsServiceTests.swift`

```swift
class CustomPromptsServiceTests: XCTestCase {
    // CRUD operations
    func testCreateCustomPrompt()
    func testReadCustomPrompts()
    func testUpdateCustomPrompt()
    func testDeleteCustomPrompt()
    func testTogglePromptActive()

    // Integration with PromptsManager
    func testCustomPromptsIncludedInRotation()
    func testInactivePromptsExcludedFromRotation()
}
```

**File:** `DandelionTests/EnhancedStatsTests.swift`

```swift
class EnhancedStatsTests: XCTestCase {
    // Stat calculations
    func testAverageWordsPerRelease()
    func testMostActiveDayOfWeek()
    func testMostActiveHour()
    func testReleasesPerMonth()
    func testLongestRelease()
    func testTotalActiveDays()
    func testFirstReleaseDate()
    func testWeeklyTrend()

    // Edge cases
    func testStatsWithNoReleases()
    func testStatsWithSingleRelease()
}
```

**File:** `DandelionTests/ExportServiceTests.swift`

```swift
class ExportServiceTests: XCTestCase {
    func testCSVExportFormat()
    func testCSVContainsAllReleases()
    func testSummaryTextGeneration()
    func testExportWithNoData()
}
```

**File:** `DandelionTests/AmbientSoundServiceTests.swift`

```swift
class AmbientSoundServiceTests: XCTestCase {
    func testInitialStateIsStopped()
    func testPlaySound()
    func testStopSound()
    func testVolumeControl()
    func testSoundLoops()
}
```

### Integration Tests

**File:** `DandelionTests/PremiumIntegrationTests.swift`

```swift
class PremiumIntegrationTests: XCTestCase {
    // End-to-end flows
    func testPurchaseAndUnlockFeatures()
    func testRestorePurchases()
    func testCustomPromptCreationRequiresPremium()
    func testThemeSwitchingRequiresPremium()
    func testMacGateRequiresPremium()
}
```

### UI Tests

**File:** `DandelionUITests/PaywallUITests.swift`

```swift
class PaywallUITests: XCTestCase {
    func testPaywallDisplaysCorrectly()
    func testPaywallCanBeDismissed()
    func testRestorePurchasesButtonExists()
    func testMacGateDisplaysOnLaunch()
}
```

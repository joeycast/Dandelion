# Dandelion - Technical Documentation

This document describes the current architecture and technical decisions for developers and agents working in this repo.

---

## Technology Stack

### Platform & Language
- **Platforms:** iOS / iPadOS / macOS (multiplatform target)
- **Language:** Swift 5
- **UI Framework:** SwiftUI (shared), with UIKit/AppKit bridges where needed
- **Deployment targets (project settings):** iOS 18.6+, macOS 15.6+
- **Bundle ID:** `app.brink13labs.Dandelion`

**Rationale:** SwiftUI multiplatform keeps the writing experience consistent across devices. Platform conditionals (`#if os(iOS)` / `#if os(macOS)`) isolate differences (safe areas, Settings scene, help book, toolbar).

### Architecture Pattern
- **Pattern:** MVVM (Model-View-ViewModel)
- **State management:** SwiftUI `@Observable` (Observation framework)
- **Persistence:** SwiftData (+ optional CloudKit for models); UserDefaults for preferences
- **Purchases:** StoreKit 2 via `PremiumManager`
- **Cloud aggregates:** CloudKit public database via `GlobalReleaseCountService`

**Rationale:** `@Observable` simplifies dependency injection through `.environment(...)` and view invalidation without `ObservableObject` boilerplate.

---

## Project Structure

Source lives under `Dandelion/`. Unit tests live in `DandelionTests/` at the repo root. There is no separate `DandelionUITests` target.

```
Dandelion/
├── DandelionApp.swift              # @main app entry, ModelContainer, environments
├── ContentView.swift               # iOS: WritingView + history sheet; macOS: MacRootView
├── Core/
│   ├── Audio/
│   │   ├── BlowDetectionService.swift    # Mic blow detection (AVAudioEngine)
│   │   └── AmbientSoundService.swift     # Looping ambient audio (Bloom)
│   ├── Data/
│   │   ├── Models/
│   │   │   └── Release.swift             # SwiftData: timestamp + wordCount only
│   │   └── Services/
│   │       ├── ReleaseHistoryService.swift
│   │       ├── ReleaseInsightsCalculator.swift
│   │       ├── ReleaseHistoryExport.swift
│   │       └── GlobalReleaseCountService.swift  # CloudKit public stats
│   ├── Design/
│   │   ├── AppearanceManager.swift       # Palettes, styles, wind animation
│   │   ├── Theme.swift                   # Typography, spacing, layout, animations
│   │   ├── Platform.swift                # UIKit/AppKit typealiases
│   │   └── ViewModifiers.swift
│   ├── Haptics/
│   │   └── HapticsService.swift
│   ├── Notifications/
│   │   ├── ReminderNotificationService.swift
│   │   └── ReminderMessageLibrary.swift
│   ├── Premium/
│   │   └── PremiumManager.swift          # StoreKit 2 “Dandelion Bloom”
│   ├── Utilities/
│   │   ├── WordCounter.swift
│   │   ├── HintResetManager.swift
│   │   └── AppStoreConfiguration.swift
│   └── Debug/
│       └── DebugLog.swift
├── Features/
│   ├── Writing/
│   │   ├── ViewModels/
│   │   │   └── WritingViewModel.swift    # WritingState machine + release orchestration
│   │   └── Views/
│   │       ├── WritingView.swift
│   │       ├── DandelionBloomView.swift  # Canvas seed bloom + wind physics
│   │       ├── AutoScrollingTextEditor.swift
│   │       └── WordAnimatedTextView.swift
│   ├── Release/
│   │   ├── Models/
│   │   │   └── Pappus.swift              # Particle model for released text
│   │   └── Views/
│   │       ├── ReleaseAnimationView.swift
│   │       ├── PappusView.swift
│   │       ├── ReleaseMessageView.swift
│   │       └── AnimatableTextView.swift
│   ├── History/
│   │   └── Views/
│   │       ├── ReleaseHistoryView.swift  # History + Insights tabs
│   │       ├── YearGridView.swift
│   │       ├── InsightsView.swift
│   │       ├── DandelionDayIcon.swift
│   │       └── StatBox.swift
│   ├── Settings/
│   │   └── Views/
│   │       ├── SettingsView.swift
│   │       ├── AppearanceSettingsView.swift
│   │       ├── AppIconSettingsView.swift
│   │       ├── BlowDetectionSettingsView.swift
│   │       ├── SoundSettingsView.swift
│   │       ├── PromptsSettingsView.swift
│   │       ├── ReminderSettingsView.swift
│   │       ├── BloomUnlockRow.swift
│   │       └── SettingsFooterView.swift
│   ├── Premium/
│   │   └── Views/
│   │       ├── BloomPaywallView.swift
│   │       ├── BloomUnlockCallout.swift
│   │       └── BloomLockedCard.swift
│   └── Prompts/
│       ├── Models/
│       │   ├── Prompt.swift              # WritingPrompt, ReleaseMessage, PromptsManager
│       │   ├── CustomPrompt.swift        # SwiftData custom prompts (Bloom)
│       │   ├── DefaultPromptSetting.swift
│       │   └── PromptGenerationSettings.swift  # AI mix weights (if present)
│       └── Services/
│           └── AppleIntelligencePromptService.swift  # FoundationModels (if present)
├── Mac/
│   ├── MacRootView.swift                 # macOS shell: writing + inspector panels
│   ├── MacSettingsView.swift             # Settings scene content
│   ├── MacCommands.swift
│   ├── MacFocusedValues.swift
│   └── MacNavigationState.swift
├── Help/
│   └── DandelionHelp.help                # macOS help book
├── Resources/
│   └── Audio/                            # ambient_*.m4a loops
├── Assets.xcassets
└── Documentation/
    └── DandelionBloom-Spec.md            # Product spec for Bloom premium

scripts/
└── run.sh                                # Preferred simulator build/install/launch

DandelionTests/                           # Unit tests (~16 files)
```

---

## Core User Flow

`WritingState` in `WritingViewModel` drives the session:

```
prompt → writing → releasing → complete → (back to) prompt
```

| State | User experience |
|-------|-----------------|
| `prompt` | Dandelion bloom + writing prompt; user starts writing |
| `writing` | Text editor active; blow detection may listen; manual “Let Go” always available |
| `releasing` | Seeds detach; text becomes pappus particles; release message appears |
| `complete` | Post-release; dandelion regrows; ready for a new prompt |

**Manual release is first-class.** Blow detection enhances the experience; it is never required. Haptics and accessibility labels support both paths.

On release, the view records metadata only (word count) via `ReleaseHistoryService` / `onReleaseTriggered` — never the written text.

---

## Key Components

### Writing (`WritingViewModel` + `WritingView`)
- Central `@Observable` state machine for text, prompts, release messages, seed detachment, and blow level UI.
- Coordinates `BlowDetectionService`, `HapticsService`, and `PromptsManager`.
- Orchestrates release timing (~9s release phase) and seed restore (~8s regrowth after return animation).
- ~140 procedural seeds (`dandelionSeedCount`).

### Blow detection (`BlowDetectionService`)
- `AVAudioEngine` + Accelerate-based frequency analysis (low-frequency wind-like noise vs speech).
- User-adjustable sensitivity (`BlowDetectionSensitivity`) and enable/disable toggles in Settings.
- Supported on iOS, iPadOS, and macOS; permission APIs differ per platform.

### Ambient sound (`AmbientSoundService`)
- Optional looping backgrounds: rain, fireplace, ocean, stream, birds (`Resources/Audio/*.m4a`).
- Preferences in UserDefaults; gated behind **Dandelion Bloom** in the writing UI.

### Release animation
- `Pappus` models characters/words as drifting particles.
- `ReleaseAnimationView` / `PappusView` / `AnimatableTextView` / `ReleaseMessageView` handle drift and messaging.
- Timing is content-dependent (message delay scales with particle end times); release message view uses a ~4.0s show delay in some paths.
- `DandelionBloomView`: Canvas + TimelineView wind physics; styles: procedural, watercolor, pencil.

### History & insights
- `Release` SwiftData model: **`timestamp` + `wordCount` only**.
- `ReleaseHistoryService`: streaks, yearly totals, calendar dates.
- `ReleaseHistoryView`: History (year grid) + Insights tabs.
- `ReleaseInsightsCalculator`: premium-oriented stats (averages, active days, time buckets, etc.).
- `ReleaseHistoryExport`: on-device CSV / shareable summary (no server).

### Global release counts (`GlobalReleaseCountService`)
- CloudKit **public** database aggregates (totals and “today” counts/words).
- Optional contribution; fails soft when CloudKit is unavailable or tests are running.
- Does not store writing content.

### Prompts
- Curated defaults in `WritingPrompt.defaults` / release messages in `Prompt.swift`.
- `PromptsManager`: random selection avoiding recent repeats; respects disabled defaults and custom prompts.
- `CustomPrompt` + `DefaultPromptSetting` SwiftData models; custom prompts require Bloom.
- **Apple Intelligence (when present):** `AppleIntelligencePromptService` uses FoundationModels where available; `PromptGenerationSettings` stores mix weights for curated/custom/AI sources. Availability is device/OS-dependent.

### Premium — Dandelion Bloom (`PremiumManager`)
- StoreKit 2 product: `com.dandelion.bloom.premium` (one-time; display price fallback `$4.99`).
- Universal purchase intent across iOS/iPadOS/macOS.
- **macOS:** full app use is gated on Bloom unlock (`MacRootView` shows paywall when locked).
- Unlock surfaces: themes/styles beyond free dark, ambient sound, custom prompts, deeper insights, export, alternate icons (see `Documentation/DandelionBloom-Spec.md`).
- DEBUG overrides for force unlock / force locked.

### Settings
- Appearance (palette, style, wind animation), app icon, blow detection, sound, prompts, reminders, Bloom unlock row, footer (App Store / legal links via `AppStoreConfiguration`).

### Notifications (`ReminderNotificationService`)
- Local daily release reminders (hour/minute, permission states, first-release nudge).
- Message copy from `ReminderMessageLibrary`.

### Haptics (`HapticsService`)
- Light taps and release/regrow patterns; UIKit impact generators / AppKit feedback; user-disableable.

### Design system
- **`AppearanceManager`:** palettes `dark` | `dawn` | `twilight` | `forest`; styles `procedural` | `watercolor` | `pencil`; wind animation with Low Power Mode respect.
- **`DandelionTheme`:** background, card, primary, accent, text, secondary, subtle, pappus colors per palette (not a single cream theme).
- **`Theme.swift`:** serif system typography, `DandelionSpacing`, `DandelionLayout`, `DandelionAnimation` presets (`gentle` 0.4s, `slow` 0.8s, `meaningful` 1.2s, `pappusFloat` 3.0s, `gentleSpring`).
- Free tier centers on **Dark** palette; additional palettes are Bloom features.

### macOS (`Mac/`)
- `MacRootView`: focused writing + inspector for history/settings-style panels.
- `MacSettingsView` + `Settings` scene; `MacCommands` / focused values for menu integration.
- Help book under `Help/DandelionHelp.help`.

### App bootstrap (`DandelionApp`)
- Builds SwiftData `ModelContainer` with schema: `Release`, `CustomPrompt`, `DefaultPromptSetting`.
- Optional CloudKit-backed configuration (`iCloudSyncEnabled`, default true) with fallbacks: preferred CloudKit → local-only → in-memory last resort.
- Injects `PremiumManager`, `AppearanceManager`, `AmbientSoundService`, `ReminderNotificationService`.
- DEBUG: optional mock release seeding for history UI.

---

## Data Persistence & Privacy

### Never persisted
- User writing content (exists only in memory for the active session).
- No content analytics, logs, or backups of what people write.

### What is persisted

| Data | Storage |
|------|---------|
| Release metadata (timestamp, word count) | SwiftData (`Release`) |
| Custom prompts text (user-authored prompts, not journal entries) | SwiftData (`CustomPrompt`) |
| Default prompt enable/disable | SwiftData (`DefaultPromptSetting`) |
| Appearance, ambient sound, blow/haptics prefs, reminders | UserDefaults |
| Bloom entitlement cache | UserDefaults + StoreKit |
| Optional global aggregates (counts only) | CloudKit public DB |
| Optional iCloud sync of SwiftData models | CloudKit (user-toggleable) |

### Privacy principles
- Microphone used only for blow detection while listening is active.
- No third-party tracking SDKs.
- Export is on-device only.
- Privacy nutrition label intent: minimal data collection.

---

## Accessibility

- Manual release is equal to blow release (VoiceOver labels, large targets).
- Dynamic Type and serif system fonts where appropriate.
- Reduce Motion / Low Power Mode considerations for wind animation.
- Dedicated `AccessibilityTests` for Let Go button state and insights labels.

---

## Testing

Unit tests live in **`DandelionTests/`** (~16 files). No UI test target currently.

| Suite | Focus |
|-------|--------|
| `WritingViewModelTests` | State transitions, canRelease, release flow |
| `PappusTests` | Particle generation from text |
| `PromptsManagerTests` | Prompt rotation, premium custom prompts, disabled defaults |
| `BlowDetectionServiceTests` | Progress / listening enablement |
| `BlowDetectionSensitivityTests` | Sensitivity presets and clamping |
| `ReleaseHistoryServiceTests` | Streaks and yearly aggregates |
| `ReleaseInsightsCalculatorTests` | Insights math |
| `GlobalReleaseCountServiceTests` | Count increment / day-key logic |
| `PremiumManagerTests` | Purchase path with stub products |
| `ReminderNotificationServiceTests` | Reminder scheduling prefs |
| `WordCounterTests` | Linguistic word counting |
| `HintResetManagerTests` | Returning-user hint reset |
| `PrivacyMessagingTests` | Privacy-facing copy/behavior |
| `AccessibilityTests` | A11y labels and control states |
| `AppStoreConfigurationTests` | Info.plist URL helpers |
| `ICloudAvailabilityTests` | Status symbol mapping |

### Running tests

```bash
xcodebuild -project Dandelion.xcodeproj -scheme Dandelion \
  -destination 'platform=iOS Simulator,name=iPhone 16' test

xcodebuild -project Dandelion.xcodeproj -scheme Dandelion \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test -only-testing:DandelionTests/WritingViewModelTests
```

---

## Build & Run

```bash
# Preferred: build, install, and launch on simulators
./scripts/run.sh

# Explicit build
xcodebuild -project Dandelion.xcodeproj -scheme Dandelion \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

`scripts/run.sh` boots configured simulators, builds with a local `.build` derived data path, installs, and launches the app. Prefer it when asked to “build and run.”

Icon helpers in `scripts/`: `generate_dandelion_icon.py`, `generate_dandelion_svg.swift` (asset tooling, not runtime).

---

## Performance Targets

- App launch: interactive quickly; SwiftData container init has CloudKit fallbacks to avoid hard failures.
- Animation: target 60fps for bloom and release particles.
- Memory: no long-lived content storage; text cleared after release.
- Battery: microphone only while blow detection is listening; ambient audio only when enabled.

---

## Future / Spec Notes

Product direction for Bloom and related features is captured in `Dandelion/Documentation/DandelionBloom-Spec.md`. Possible expansions (widgets, Shortcuts, watchOS) remain product decisions — implement only when explicitly requested.

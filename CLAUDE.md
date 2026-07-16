# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
# Build and run on simulator (PREFERRED - use this when asked to "build and run")
./scripts/run.sh

# Build the app
xcodebuild -project Dandelion.xcodeproj -scheme Dandelion -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run all tests
xcodebuild -project Dandelion.xcodeproj -scheme Dandelion -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a specific test class
xcodebuild -project Dandelion.xcodeproj -scheme Dandelion -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:DandelionTests/WritingViewModelTests

# Run a specific test method
xcodebuild -project Dandelion.xcodeproj -scheme Dandelion -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:DandelionTests/WritingViewModelTests/testInitialState
```

Multiplatform target: **iOS / iPadOS / macOS**. Project deployment targets are currently iOS 18.6+ and macOS 15.6+. Prefer `./scripts/run.sh` over ad-hoc xcodebuild for local simulator runs.

## Architecture Overview

**Pattern:** MVVM with SwiftUI using `@Observable` (Observation framework)

**Core flow:** `WritingState` enum drives the writing session:
- `prompt` → `writing` → `releasing` → `complete` → back to `prompt`

**Entry:** `DandelionApp` → `ContentView` (iOS: `WritingView` + history sheet; macOS: `MacRootView`)

**Key components:**

| Component | Purpose |
|-----------|---------|
| `WritingViewModel` | State machine: text, prompts, blow UI, seed detach/restore, release orchestration |
| `BlowDetectionService` | AVAudioEngine mic monitoring; adjustable sensitivity; iOS + macOS |
| `AmbientSoundService` | Looping ambient audio (Bloom); rain/fireplace/ocean/stream/birds |
| `DandelionBloomView` | Canvas + TimelineView ~140 seeds with wind physics; style variants |
| `ReleaseAnimationView` / `Pappus` | Text → floating pappus particles + release message |
| `AppearanceManager` + `Theme` | Palettes/styles + typography, spacing, layout, animation tokens |
| `PromptsManager` | Prompt/message selection avoiding recent repeats; custom + disabled defaults |
| `ReleaseHistoryService` | SwiftData release metadata (timestamp, word count only) |
| `ReleaseInsightsCalculator` | Premium insights from history |
| `GlobalReleaseCountService` | CloudKit public aggregate counts (no content) |
| `PremiumManager` | StoreKit 2 “Dandelion Bloom” entitlement |
| `ReminderNotificationService` | Local daily reminders |
| `HapticsService` | Tap / release haptic patterns |

**Project structure:**
```
Dandelion/
├── DandelionApp.swift, ContentView.swift
├── Core/
│   ├── Audio/           # BlowDetection, AmbientSound
│   ├── Data/            # Release model, history/insights/export, global CloudKit counts
│   ├── Design/          # AppearanceManager, Theme, Platform, ViewModifiers
│   ├── Haptics/
│   ├── Notifications/   # Reminders
│   ├── Premium/         # PremiumManager (StoreKit 2)
│   ├── Utilities/       # WordCounter, HintResetManager, AppStoreConfiguration
│   └── Debug/
├── Features/
│   ├── Writing/         # WritingViewModel, WritingView, DandelionBloomView
│   ├── Release/         # Pappus models + animation views
│   ├── History/         # Year grid, Insights
│   ├── Settings/        # Appearance, sound, blow, prompts, reminders, icons
│   ├── Premium/         # Bloom paywall / unlock UI
│   └── Prompts/         # Defaults, custom prompts, optional Apple Intelligence
├── Mac/                 # MacRootView, settings scene, commands
├── Help/                # macOS help book
├── Resources/Audio/     # Ambient loops
└── Documentation/       # Bloom product spec

DandelionTests/          # ~16 unit test files (no UITests target)
scripts/run.sh           # Preferred simulator build & launch
```

See **TECHNICAL.md** for the full architecture write-up.

## Critical Design Constraints

- **No content persistence:** User journal writing exists only in memory. Never store, cache, or log the text they write. SwiftData may store release **metadata** (timestamp, word count) and user-authored **custom prompts** — not journal entries.
- **Accessibility-first:** Manual release is a first-class feature, not a fallback for blow detection.
- **Animation performance:** Target 60fps for `DandelionBloomView` and release animations.
- **macOS:** Bloom gates the full Mac experience; keep platform `#if os` boundaries intact.

## Animation System

Release is orchestrated primarily by `WritingViewModel`:
1. Seeds detach from the dandelion (shuffled order, staggered timing)
2. Written characters become `Pappus` particles and drift away
3. Release message appears (timing scales with particle duration; some paths use ~4.0s delay)
4. Release phase ~9s, then complete; dandelion returns and seeds restore (~8s restore)
5. Flow returns toward a fresh prompt

`DandelionBloomView` uses a custom Canvas simulation with wind physics. Styles: procedural, watercolor, pencil.

## Theme System

Colors come from **`AppearanceManager.theme`** (`DandelionTheme`), not hard-coded soft cream defaults.

Palettes: **Dark** (free default), **Dawn**, **Twilight**, **Forest** (additional palettes are Bloom).

Dark example tokens:
- Background: black
- Text/primary: pale yellow (RGB 0.98, 0.93, 0.75)
- Accent: gentle gold

Typography/spacing/animation live in `Theme.swift` (serif system fonts, `DandelionSpacing`, `DandelionLayout`, `DandelionAnimation`).

Animation presets: `gentle` (0.4s), `slow` (0.8s), `meaningful` (1.2s), `pappusFloat` (3.0s), `gentleSpring`.

## Premium (Dandelion Bloom)

- StoreKit 2 product `com.dandelion.bloom.premium` via `PremiumManager`
- Typical unlocks: extra palettes/styles, ambient sound, custom prompts, deeper insights, history export, alternate icons
- Product details: `Dandelion/Documentation/DandelionBloom-Spec.md`

## Testing

`DandelionTests/` includes ~16 suites, including:
- `WritingViewModelTests`, `PappusTests`, `PromptsManagerTests`
- `BlowDetectionServiceTests`, `BlowDetectionSensitivityTests`
- `ReleaseHistoryServiceTests`, `ReleaseInsightsCalculatorTests`
- `GlobalReleaseCountServiceTests`, `PremiumManagerTests`
- `ReminderNotificationServiceTests`, `WordCounterTests`, `HintResetManagerTests`
- `PrivacyMessagingTests`, `AccessibilityTests`, `AppStoreConfigurationTests`, `ICloudAvailabilityTests`

---

## Product Context

### What This App Does
Dandelion is a journaling app where writings are never saved. Users write to release thoughts, then let them go by blowing into the microphone (or tapping). Words scatter and drift away like dandelion seeds. Tagline: *"Write and Let Go."*

### Communication Guidelines
The product owner is non-technical. When communicating:
- Describe changes in terms of user experience, not code
- Make technical decisions autonomously
- Only ask about choices affecting visual design, prompts/messages, or interaction feel
- Document technical decisions in TECHNICAL.md

### Design Vision
- Apple Design Award worthy aesthetics
- Meaningful, slow, intentional interactions
- Serif typography, serene mood
- Hand-drawn or Alto's Adventure artistic style

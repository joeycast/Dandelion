# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
# Build the app
xcodebuild -project Dandelion.xcodeproj -scheme Dandelion -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run all tests
xcodebuild -project Dandelion.xcodeproj -scheme Dandelion -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a specific test class
xcodebuild -project Dandelion.xcodeproj -scheme Dandelion -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:DandelionTests/WritingViewModelTests

# Run a specific test method
xcodebuild -project Dandelion.xcodeproj -scheme Dandelion -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:DandelionTests/WritingViewModelTests/testInitialState
```

## Architecture Overview

**Pattern:** MVVM with SwiftUI using `@Observable` macro (iOS 17+)

**Core Flow:** `WritingState` enum drives the entire app experience:
- `prompt` → `writing` → `releasing` → `complete` → back to `prompt`

**Key Components:**

| Component | Purpose |
|-----------|---------|
| `WritingViewModel` | Central state machine managing text, state transitions, and blow detection |
| `BlowDetectionService` | AVAudioEngine-based microphone input monitoring for blow-to-release |
| `DandelionBloomView` | Canvas + TimelineView rendering 140 animated seeds with wind physics |
| `ReleaseAnimationView` | Converts text into floating pappus particles that drift away |
| `Theme` | Design system tokens (colors, typography, spacing, animations) |
| `PromptsManager` | Intelligent prompt/message selection avoiding recent repeats |

**Project Structure:**
```
Dandelion/
├── App/                    # App entry point
├── Core/
│   ├── Audio/              # BlowDetectionService
│   ├── Design/             # Theme system
│   └── Debug/              # Debug utilities
├── Features/
│   ├── Writing/            # Main writing interface (Views + ViewModels)
│   ├── Release/            # Pappus animation system
│   └── Prompts/            # Prompt/message models
└── DandelionTests/         # Unit tests
```

## Critical Design Constraints

- **No content persistence:** User writing exists only in memory. Never store, cache, or log text content.
- **Accessibility-first:** Manual release is a first-class feature, not a fallback for blow detection.
- **Animation performance:** Target 60fps for DandelionBloomView and release animations.

## Animation System

The release animation is choreographed over ~9 seconds:
1. Seeds begin detaching from dandelion (~140ms apart, shuffled order)
2. Text characters become individual `Pappus` particles
3. Release message appears at 4.0s
4. Fade out completes at ~8s
5. Seed restoration animation (3s) returns dandelion to full state

`DandelionBloomView` uses a custom simulation with wind physics rendered via Canvas.

## Theme System

Colors, typography, and spacing are centralized in `Theme.swift`. Currently using dark theme:
- Background: Black
- Text/Primary: Pale yellow (RGB: 0.98, 0.93, 0.75)
- Accent: Gentle gold

Animation presets: `gentle` (0.4s), `slow` (0.8s), `meaningful` (1.2s), `pappusFloat` (3.0s)

## Testing

Three test files covering:
- `WritingViewModelTests` - State transitions and validation logic
- `PappusTests` - Particle model behavior
- `PromptsManagerTests` - Prompt selection and rotation

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

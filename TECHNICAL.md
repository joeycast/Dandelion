# Dandelion - Technical Documentation

This document contains technical decisions and architecture details for future developers.

---

## Technology Stack

### Platform & Language
- **Platform:** iOS 17.0+ / iPadOS 17.0+
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (primary) with UIKit integration where needed
- **Minimum Deployment:** iOS 17.0

**Rationale:** SwiftUI provides modern, declarative UI development with excellent animation support. iOS 17 minimum allows use of modern APIs while maintaining broad device compatibility.

### Architecture Pattern
- **Pattern:** MVVM (Model-View-ViewModel)
- **State Management:** SwiftUI's native @Observable macro (iOS 17+)
- **Navigation:** SwiftUI NavigationStack

**Rationale:** MVVM with SwiftUI is Apple's recommended approach. The @Observable macro simplifies state management compared to ObservableObject.

---

## Project Structure

```
Dandelion/
├── App/
│   └── DandelionApp.swift           # App entry point
├── Features/
│   ├── Writing/
│   │   ├── Views/
│   │   │   ├── WritingView.swift    # Main writing interface
│   │   │   └── Components/          # Reusable view components
│   │   ├── ViewModels/
│   │   │   └── WritingViewModel.swift
│   │   └── Models/
│   ├── Release/
│   │   ├── Views/
│   │   │   ├── ReleaseAnimationView.swift
│   │   │   └── PappusView.swift     # Individual floating element
│   │   └── ViewModels/
│   │       └── ReleaseViewModel.swift
│   ├── Prompts/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Models/
│   │       └── Prompt.swift
│   └── Premium/
│       ├── Views/
│       ├── ViewModels/
│       └── Services/
│           └── StoreKitService.swift
├── Core/
│   ├── Audio/
│   │   └── BlowDetectionService.swift  # Microphone input processing
│   ├── Design/
│   │   ├── Theme.swift              # Colors, typography, spacing
│   │   ├── Fonts/                   # Custom font files
│   │   └── Assets/                  # Hand-drawn imagery
│   ├── Animation/
│   │   └── PappusAnimator.swift     # Physics-based drift animation
│   └── Accessibility/
│       └── AccessibilityHelpers.swift
├── Resources/
│   ├── Assets.xcassets
│   ├── Localizable.strings
│   └── Prompts.json                 # Pre-writing prompts data
└── Tests/
    ├── DandelionTests/              # Unit tests
    └── DandelionUITests/            # UI tests
```

---

## Key Technical Components

### 1. Blow Detection (Audio Input)

**Approach:** AVAudioEngine with audio level monitoring

```swift
// Simplified concept
class BlowDetectionService {
    - Uses AVAudioEngine to tap microphone input
    - Monitors audio levels in real-time
    - Detects sustained airflow (blow) vs. speech/noise
    - Triggers release animation when threshold met
}
```

**Key considerations:**
- Request microphone permission with clear purpose string
- Distinguish between blowing and ambient noise/speech
- Provide haptic feedback when blow is detected
- Graceful fallback if permission denied

### 2. Pappus Drift Animation

**Approach:** Custom particle-like system using SwiftUI animations + physics

- Each word/letter becomes an individual "pappus" view
- Physics-inspired motion: initial burst, then gentle floating drift
- Randomized trajectories for organic feel
- Opacity fade as elements leave screen
- Performance optimized for many simultaneous elements

### 3. Manual Release Gesture

**Options:**
- Long press and drag upward (like releasing into the sky)
- Swipe up gesture
- Tap a visual "release" element (dandelion illustration)

All trigger the same beautiful pappus animation.

### 4. Data Persistence

**Critical:** NO persistence of user writing content.

- Text exists only in memory during active session
- Cleared completely on release or app termination
- No analytics on content
- No backups, no caching

**What IS persisted:**
- User preferences (theme, settings)
- Premium purchase status (via StoreKit)
- Usage statistics (sessions count, not content)

Storage: UserDefaults for preferences, Keychain for sensitive data, StoreKit for purchases.

### 5. Premium Features (StoreKit 2)

**Implementation:** StoreKit 2 for in-app purchases

- Non-consumable products for one-time unlocks
- Proper receipt validation
- Restore purchases support
- Graceful offline handling

---

## Design System

### Colors (Semantic)
```swift
extension Color {
    static let dandelionBackground = // Soft white/cream
    static let dandelionPrimary = // Pale yellow
    static let dandelionAccent = // Gentle gold
    static let dandelionText = // Warm dark gray
    static let dandelionSecondary = // Light gray for hints
}
```

### Typography
- Primary: Serif font (system or custom)
- Consider: Playfair Display, Libre Baskerville, or system serif
- Large, readable sizes with generous line height

### Spacing
- Generous whitespace throughout
- Content breathes
- Touch targets exceed 44pt minimum

---

## Accessibility

### VoiceOver
- All interactive elements properly labeled
- Release action announced
- Post-release messages read aloud

### Motor Accessibility
- Manual release as first-class feature
- Large touch targets
- No time-sensitive interactions

### Visual Accessibility
- Dynamic Type support
- Sufficient color contrast
- Reduce Motion support (simpler animations)

### Respiratory Accessibility
- Manual release prominently offered
- No requirement to blow
- Equal experience either way

---

## Testing Strategy

### Unit Tests
- BlowDetectionService threshold logic
- ViewModel state transitions
- Prompt loading and randomization
- Premium purchase status logic

### UI Tests
- Writing flow completion
- Release animation triggers
- Manual release gesture
- Accessibility audit

### Manual Testing Checklist
- [ ] Fresh install experience
- [ ] Microphone permission flows (grant/deny)
- [ ] Release animation smoothness
- [ ] Various text lengths (single word to paragraphs)
- [ ] iPad layout
- [ ] Dynamic Type sizes
- [ ] VoiceOver navigation
- [ ] Reduce Motion enabled

---

## Performance Targets

- App launch: < 1 second to interactive
- Animation: Consistent 60fps
- Memory: Minimal footprint (no content storage)
- Battery: Microphone only active during blow detection

---

## Privacy

- No personal data collection
- No content analytics
- No third-party SDKs that track users
- Microphone used only for blow detection
- Privacy nutrition label: Minimal data collected

---

## Future Technical Considerations

- watchOS companion (quick release)
- Widgets (daily prompt)
- Shortcuts integration
- CloudKit for preferences sync (no content)
- Additional themes (asset bundles)

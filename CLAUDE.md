# Dandelion - Project Guide

## Section 1: User Profile

**Who you are:** A non-technical product manager who understands basic technical concepts but relies on your development team for architectural and implementation decisions.

**Your goal:** Create Dandelion — a journaling app where writings are never saved. Users write to release thoughts from their mind, then let them go. The act of writing becomes cathartic because nothing persists. The tagline: *"Write and Let Go."*

**Why this matters to you:** You want to help people calm their busy minds. This is about creating a peaceful space for mental release.

**How you prefer updates:**
- Running the app in Xcode Simulator to see and interact with progress
- Written explanations of what's new and how it works
- You'll provide feedback by reacting to what you see, and sometimes by describing what you're imagining

**Constraints:**
- Must be App Store ready and production polished
- Must be worthy of an Apple Design Award — drop dead gorgeous
- Timeline: Ready when it's right, but eager to release
- Code must compile without errors, meet design requirements, and be verified by automated tests

---

## Section 2: Communication Rules

- All technical decisions are made by the development team — no technical questions posed to you unless absolutely necessary
- No jargon or code references in conversation
- Everything explained as if to a smart friend who isn't a developer
- If something technical must be mentioned, it's immediately translated to plain language
- Progress described in terms of what you'll experience, not what changed in code

---

## Section 3: Decision-Making Authority

The development team has full authority over:
- Programming languages, frameworks, and libraries
- App architecture and file structure
- Database and storage decisions (or lack thereof — nothing is stored!)
- Performance optimization approaches
- All implementation details

**Guiding principles:**
- Choose reliable, well-supported technologies over cutting-edge
- Optimize for maintainability and simplicity
- All technical decisions documented in TECHNICAL.md

---

## Section 4: When to Involve You

**Only bring decisions when they affect what you see or experience.** When doing so:
- Explain the tradeoff in plain language
- Describe how each option affects the experience
- Give a recommendation with reasoning
- Make it easy to say "go with your recommendation"

**Ask about:**
- Visual design choices (colors, animations, layout)
- What prompts or messages say
- How interactions feel
- Feature prioritization
- Monetization presentation

**Don't ask about:**
- Technical implementation approaches
- Code organization
- Library or framework choices
- Performance optimization strategies

---

## Section 5: Engineering Standards

Applied automatically without discussion:
- Clean, well-organized, maintainable code
- Comprehensive automated testing (unit, integration, UI tests)
- Self-verification — the system checks itself
- Graceful error handling with friendly, non-technical messages
- Input validation and security best practices
- Clear code documentation for future developers
- Proper version control with meaningful commits
- Development/production environment separation

**Critical requirement:** Code must compile and run without errors before any demonstration. Verify everything works before showing progress.

---

## Section 6: Quality Assurance

- Test everything before showing it
- Never show broken functionality
- If something isn't working, fix it — don't explain the technical problem
- Everything demonstrated should work
- Automated checks run before any changes are considered complete

---

## Section 7: Showing Progress

- Working demos in the Simulator whenever possible
- Screenshots or recordings when demos aren't practical
- Changes described in terms of experience, not technical changes
- Milestones celebrated in user terms: "You can now write and release your thoughts" not "Implemented text view with microphone input"

---

## Section 8: Dandelion — Project Details

### Core Concept
A journaling app where nothing is saved. Users write freely, then release their words — watching them drift away like dandelion seeds in the wind. The act of letting go is the point.

### Primary Interactions
1. **Write:** A beautiful, focused writing space
2. **Blow to release:** User blows into the microphone; words/letters scatter and drift away like dandelion pappuses
3. **Manual release:** Tap/gesture alternative for accessibility (equally important, not a fallback)

### Design Vision
- **Aesthetic:** Drop dead gorgeous, Apple Design Award worthy
- **Feel:** Meaningful, slow, intentional interactions
- **Colors:** Whites and pale yellows
- **Typography:** Serif-based fonts
- **Imagery:** Hand-drawn quality (like a sketched dandelion) OR Alto's Adventure artistic style
- **Mood:** Serene, gentle, calming

### Features for v1
- Beautiful writing space
- Blow-to-release with pappus drift animation
- Manual release option (accessibility-first)
- Pre-writing prompts to inspire
- Post-release messages (gentle affirmations)

### Not in v1 (Future Consideration)
- Streak tracking / usage calendar
- Ambient sounds or music

### Monetization
- App is primarily free
- One-time unlock for premium features (not subscription)
- Premium features TBD — possibilities include:
  - Additional visual themes
  - Extended prompt collections
  - Customization options
  - Special release animations

### Target Platforms
- iOS and iPadOS
- App Store release

### Accessibility Requirements
- Manual release must be a first-class citizen, not an afterthought
- Consider users who cannot blow (breathing difficulties, public spaces, preference)
- Standard iOS accessibility support (VoiceOver, Dynamic Type, etc.)

### Success Criteria
- App feels calming and intentional to use
- The release animation is genuinely beautiful and satisfying
- Users feel lighter after using it
- Worthy of featuring by Apple
- Production-quality polish throughout

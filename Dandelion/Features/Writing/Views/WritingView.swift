//
//  WritingView.swift
//  Dandelion
//
//  Main writing experience view
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct WritingView: View {
    let topSafeArea: CGFloat
    let bottomSafeArea: CGFloat
    let onShowHistory: () -> Void
    let onSwipeEligibilityChange: (Bool) -> Void
    let isActive: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(AppearanceManager.self) private var appearance
    @Environment(PremiumManager.self) private var premium
    @Environment(AmbientSoundService.self) private var ambientSound
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \CustomPrompt.createdAt) private var customPrompts: [CustomPrompt]
    @Query private var defaultPromptSettings: [DefaultPromptSetting]
    @State private var viewModel = WritingViewModel()
    @State private var isTextEditorFocused: Bool = false
    @State private var animateLetters: Bool = false
    @State private var promptOpacity: Double = 1
    @State private var mainContentOpacity: Double = 0
    @State private var textScrollOffset: CGFloat = 0
    @State private var capturedScrollOffset: CGFloat = 0
    @State private var releaseDandelionTopPadding: CGFloat? = nil
    @State private var lastWritingDandelionTopPadding: CGFloat = 0
    @State private var releaseTextSnapshot: String = ""
    @State private var showWrittenText: Bool = true
    @State private var showAnimatedText: Bool = false
    @State private var releaseVisibleHeight: CGFloat = 0
    @State private var lastWritingAreaHeight: CGFloat = 0
    @State private var releaseClipOffset: CGFloat = 0
    @State private var fadeOutLetters: Bool = false
    @State private var lastWritingState: WritingState = .prompt
    @State private var suppressPromptLayoutAnimation: Bool = false

#if os(macOS)
    private static let debugShowDandelionLayer = false
    private static let debugShowReleaseLayers = false
    private static let debugShowReleaseMetrics = false
#endif
    @State private var showBloomPaywall: Bool = false
    @State private var isSettingsPresented: Bool = false
    @State private var showLetGoHint: Bool = false
    @AppStorage("hasSeenLetGoHint") private var hasSeenLetGoHint: Bool = false
    @AppStorage("hasUsedPromptTap") private var hasUsedPromptTap: Bool = false
    private static var hasCheckedHintReset = false
    @Namespace private var promptNamespace
    @State private var hasShownInitialPrompt: Bool = false
    @State private var isDandelionWindAnimating: Bool = true
    @State private var dandelionWindAnimationTask: Task<Void, Never>?

    private struct LayoutMetrics {
        let safeAreaTop: CGFloat
        let safeAreaBottom: CGFloat
        let fullScreenSize: CGSize
        let dandelionHeight: CGFloat
        let dandelionTopPadding: CGFloat
        let releaseDandelionTop: CGFloat
        let effectiveDandelionTopPadding: CGFloat
        let headerSpaceHeight: CGFloat
        let promptMessageTopPadding: CGFloat
    }

    init(
        topSafeArea: CGFloat = 0,
        bottomSafeArea: CGFloat = 0,
        onShowHistory: @escaping () -> Void = {},
        onSwipeEligibilityChange: @escaping (Bool) -> Void = { _ in },
        isActive: Bool = true
    ) {
        self.topSafeArea = topSafeArea
        self.bottomSafeArea = bottomSafeArea
        self.onShowHistory = onShowHistory
        self.onSwipeEligibilityChange = onSwipeEligibilityChange
        self.isActive = isActive
    }

    var body: some View {
        GeometryReader { geometry in
            writingLayoutView(in: geometry)
        }
        .animation(DandelionAnimation.slow, value: viewModel.writingState)
        .onAppear {
            if !isActive {
                viewModel.blowDetection.stopListening()
                viewModel.showBlowIndicator = false
                ambientSound.stop()
            }
            if isPromptVisible {
                fadeInPrompt()
            }
            withAnimation(.easeInOut(duration: 0.9)) {
                mainContentOpacity = 1
            }
            setupReleaseTracking()
            syncCustomPrompts()
            checkHintResetForReturningUser()
            onSwipeEligibilityChange(isPromptVisible)
        }
        .onChange(of: customPrompts) { _, _ in
            syncCustomPrompts()
        }
        .onChange(of: defaultPromptSettings) { _, _ in
            syncCustomPrompts()
        }
        .onChange(of: premium.isBloomUnlocked) { _, _ in
            syncCustomPrompts()
            handleAmbientSound(for: viewModel.writingState)
        }
        .onChange(of: viewModel.writingState) { _, newValue in
            handleAmbientSound(for: newValue)
            handleDandelionWindAnimation(for: newValue)
        }
        .onChange(of: ambientSound.isEnabled) { _, _ in
            handleAmbientSound(for: viewModel.writingState)
        }
        .onChange(of: ambientSound.selectedSound) { _, _ in
            handleAmbientSound(for: viewModel.writingState)
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                handleAmbientSound(for: viewModel.writingState)
            } else {
                viewModel.blowDetection.stopListening()
                viewModel.showBlowIndicator = false
                ambientSound.stop()
            }
        }
        .onChange(of: viewModel.currentPrompt?.id) { _, _ in
            if isPromptVisible {
                fadeInPrompt()
            }
            if WritingViewModel.debugReleaseFlow {
                debugLog(
                    "[ReleaseFlow] promptChanged state=\(viewModel.writingState) id=\(viewModel.currentPrompt?.id ?? "nil")"
                )
            }
        }
        .sheet(isPresented: $showBloomPaywall) {
            BloomPaywallView(onClose: { showBloomPaywall = false })
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
                .preferredColorScheme(appearance.colorScheme)
        }
        .onChange(of: isSettingsPresented) { _, isPresented in
            if !isPresented {
                // Reload prompt configuration when settings closes
                syncCustomPrompts()
            }
        }
        .overlay {
            if showLetGoHint {
                letGoHintOverlay
            }
        }
    }

    @ViewBuilder
    private func writingLayoutView(in geometry: GeometryProxy) -> some View {
        let layout = layoutMetrics(in: geometry)

        ZStack {
            // Background
            appearance.theme.background
                .ignoresSafeArea()
                .onTapGesture {
                    isTextEditorFocused = false
                }

            Group {
                // Content (prompt text, writing area, buttons) - fades in/out
                contentView(
                    in: geometry.size,
                    safeAreaBottom: layout.safeAreaBottom,
                    safeAreaTop: layout.safeAreaTop,
                    headerSpaceHeight: layout.headerSpaceHeight,
                    fullScreenSize: layout.fullScreenSize
                )
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if isWriting || isReleasing {
                            bottomBar(bottomInset: layout.safeAreaBottom)
                                // Animate in normally, but disappear instantly to avoid
                                // clipping through the appearing prompt buttons
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .identity
                                ))
                        }
                    }
                    .zIndex(0)

                // Single persistent dandelion - lives above all content, animates size and position
                VStack {
                    dandelionIllustration(height: layout.dandelionHeight)
                    Spacer()
                }
                .padding(.top, layout.effectiveDandelionTopPadding)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .animation(.easeInOut(duration: 1.2), value: isPromptState)
                .animation(.easeInOut(duration: 1.2), value: layout.dandelionHeight)
                .animation(.easeInOut(duration: 1.2), value: viewModel.isDandelionReturning)
                .animation(.easeInOut(duration: 1.2), value: releaseDandelionTopPadding)
                .animation(nil, value: viewModel.writingState)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .zIndex(1)

                // Release message overlay
                if isReleasing {
                    releaseMessageOverlay(layout: layout)
                        .zIndex(3)
                }
            }
            .opacity(mainContentOpacity)
        }
#if os(macOS)
        // macOS: Render animated text as overlay to ensure it floats above dandelion
        // Only render when needed to avoid first-release initialization glitches
        .overlay {
            if showAnimatedText {
                macOSAnimatedTextOverlay(
                    in: geometry.size,
                    headerSpaceHeight: layout.headerSpaceHeight,
                    fullScreenSize: layout.fullScreenSize
                )
            }
        }
#endif
        .onChange(of: viewModel.writingState) { _, newValue in
            if WritingViewModel.debugReleaseFlow {
                debugLog(
                    "[ReleaseFlow] writingState -> \(newValue) prompt=\(viewModel.currentPrompt?.id ?? "nil")"
                )
            }
            if newValue == .releasing {
                logReleaseTiming("state=releasing")
                // Capture scroll offset only if keyboard is still up (blow-triggered release).
                // For manual release, the button action already captured it before dismissing keyboard.
                // On macOS, always capture since there's no keyboard.
#if os(macOS)
                capturedScrollOffset = textScrollOffset
#else
                if isTextEditorFocused {
                    capturedScrollOffset = textScrollOffset
                }
#endif
                releaseDandelionTopPadding = lastWritingDandelionTopPadding
                releaseTextSnapshot = viewModel.writtenText
                showAnimatedText = false
                fadeOutLetters = false
                releaseVisibleHeight = lastWritingAreaHeight
                if WritingViewModel.debugReleaseFlow {
                    debugLog(
                        "[ReleaseFlow] release heights snapshot area=\(lastWritingAreaHeight) visible=\(releaseVisibleHeight)"
                    )
                }
                // Note: Seed detachment is now handled in triggerRelease() for atomic state update
                // Show animated text and hide written text together for smooth handoff
                showAnimatedText = true
                animateLetters = true
                logReleaseTiming("animatedText=visible")
                showWrittenText = false
                // Start with clip at bounds, then animate it open to release characters upward
                releaseClipOffset = 0
                let releaseClipDuration: Double = {
#if os(macOS)
                    return 3.2
#else
                    return 2.0
#endif
                }()
                withAnimation(.easeInOut(duration: releaseClipDuration)) {
#if os(macOS)
                    // macOS needs more headroom for characters to float past the header
                    releaseClipOffset = 1000
#else
                    releaseClipOffset = 200
#endif
                }
            }
            // Update focus state after releasing check (so we can detect if keyboard was up)
            isTextEditorFocused = newValue == .writing
            if newValue == .writing {
                lastWritingDandelionTopPadding = layout.dandelionTopPadding
                // Show hint on first time writing
                if !hasSeenLetGoHint {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showLetGoHint = true
                        }
                        hasSeenLetGoHint = true
                    }
                }
            }
            if newValue == .prompt || newValue == .complete || newValue == .writing {
                animateLetters = false
                fadeOutLetters = false
                releaseDandelionTopPadding = nil
                showWrittenText = true
                showAnimatedText = false
                releaseVisibleHeight = 0
                releaseClipOffset = 0
            }
            if newValue == .prompt && lastWritingState == .complete {
                suppressPromptLayoutAnimation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    suppressPromptLayoutAnimation = false
                }
            }
            lastWritingState = newValue
            // Don't fade prompt on state change - let the prompt ID change handler do it
            // This prevents double-animation when transitioning from release to prompt
            if newValue == .writing {
                promptOpacity = 1
            }
            onSwipeEligibilityChange(isPromptVisible)
        }
    }

#if os(macOS)
    @ViewBuilder
    private func macOSAnimatedTextOverlay(
        in size: CGSize,
        headerSpaceHeight: CGFloat,
        fullScreenSize: CGSize
    ) -> some View {
        let baseHorizontalPadding = DandelionSpacing.screenEdge - 5
        let horizontalPadding = max(
            baseHorizontalPadding,
            (size.width - DandelionLayout.maxWritingWidth) / 2
        )
        let lineWidth = size.width - (horizontalPadding * 2)
        // Add buffer to prevent bottom row cutoff
        let overlayVisibleHeight = (releaseVisibleHeight > 0 ? releaseVisibleHeight : lastWritingAreaHeight) + 30

        let topOverflowForAnimation: CGFloat = 500

        AnimatableTextView(
            text: releaseTextSnapshot,
            font: .dandelionWriting,
            uiFont: .dandelionWriting,
            textColor: theme.text,
            lineWidth: lineWidth,
            isAnimating: animateLetters,
            fadeOutTrigger: fadeOutLetters,
            screenSize: fullScreenSize,
            visibleHeight: overlayVisibleHeight,
            scrollOffset: capturedScrollOffset,
            horizontalOffset: horizontalPadding
        )
        .padding(.top, max(0, 8 - capturedScrollOffset))
        .allowsHitTesting(false)
        // No horizontal padding - let particles float freely across the full window
        // Position at top of writing area:
        // - headerSpaceHeight: space for dandelion
        // - ~18pt: height adjustment for prompt text line
        // - DandelionSpacing.sm: writingArea top padding
        // - minus 500pt for the overflow built into AnimatableTextView
        .padding(.top, headerSpaceHeight + 18 + DandelionSpacing.sm - topOverflowForAnimation)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
#endif

    private func releaseMessageOverlay(layout: LayoutMetrics) -> some View {
        #if os(macOS)
        let base = ReleaseMessageView(
            releaseMessage: viewModel.currentReleaseMessage.text,
            messageTopPadding: layout.promptMessageTopPadding,
            onMessageAppear: {
                withAnimation(.easeInOut(duration: 1.2)) {
                    releaseDandelionTopPadding = layout.releaseDandelionTop
                }
                fadeOutLetters = true
                logReleaseTiming("releaseMessage=appear")
                viewModel.startDandelionReturn()
            },
            onMessageFadeStart: {
                viewModel.startSeedRestoreNow()
            },
            onComplete: {}
        )
        #else
        let base = ReleaseMessageView(
            releaseMessage: viewModel.currentReleaseMessage.text,
            messageTopPadding: layout.promptMessageTopPadding,
            onMessageAppear: {
                withAnimation(.easeInOut(duration: 1.2)) {
                    releaseDandelionTopPadding = layout.releaseDandelionTop
                }
                fadeOutLetters = true
                logReleaseTiming("releaseMessage=appear")
                viewModel.startDandelionReturn()
            },
            onMessageFadeStart: {
                viewModel.startSeedRestoreNow()
            },
            onComplete: {}
        )
        .ignoresSafeArea()
        #endif

        return base
            .onAppear {
                if WritingViewModel.debugReleaseFlow {
                    debugLog("[ReleaseFlow] ReleaseMessageView onAppear")
                }
            }
            .onDisappear {
                if WritingViewModel.debugReleaseFlow {
                    debugLog("[ReleaseFlow] ReleaseMessageView onDisappear")
                }
            }
            .zIndex(1)
            .allowsHitTesting(false)
    }

    private var isPromptState: Bool {
        viewModel.writingState == .prompt || viewModel.writingState == .complete
    }

    private var isPromptVisible: Bool {
        viewModel.writingState == .prompt
    }

    private var isPromptHeaderVisible: Bool {
        viewModel.writingState == .prompt || viewModel.writingState == .writing
    }

    private var isWriting: Bool {
        viewModel.writingState == .writing
    }

    private var isReleasing: Bool {
        viewModel.writingState == .releasing
    }

    private var theme: DandelionTheme {
        appearance.theme
    }

    private func logReleaseTiming(_ label: String) {
        guard WritingViewModel.debugReleaseFlow else { return }
        guard let releaseStartTime = viewModel.releaseStartTime else {
            debugLog("[ReleaseFlow] \(label) (no start time)")
            return
        }
        let elapsed = Date().timeIntervalSinceReferenceDate - releaseStartTime
        debugLog(String(format: "[ReleaseFlow] %@ +%.3fs", label, elapsed))
    }

    private func layoutMetrics(in geometry: GeometryProxy) -> LayoutMetrics {
        let safeAreaTop = topSafeArea
        let safeAreaBottom = max(bottomSafeArea, geometry.safeAreaInsets.bottom)
        let fullScreenSize = CGSize(
            width: geometry.size.width,
            height: geometry.size.height + safeAreaTop + safeAreaBottom
        )

        let dandelionSmallHeight = DandelionLayout.dandelionSmallHeight
        let dandelionLargeHeight = DandelionLayout.dandelionLargeHeight
        let dandelionHeight: CGFloat = (isPromptState || viewModel.isDandelionReturning)
            ? dandelionLargeHeight
            : dandelionSmallHeight

        let dandelionBaseTop = safeAreaTop + DandelionLayout.minTopMargin
        let proportionalOffset = DandelionLayout.proportionalOffset(screenHeight: geometry.size.height)
        let dandelionTopPadding: CGFloat = (isPromptState || viewModel.isDandelionReturning || isReleasing)
            ? dandelionBaseTop + proportionalOffset
            : dandelionBaseTop
        let releaseDandelionTop = dandelionBaseTop + proportionalOffset
        let effectiveDandelionTopPadding = isReleasing
            ? (releaseDandelionTopPadding ?? lastWritingDandelionTopPadding)
            : dandelionTopPadding

        #if os(macOS)
        let promptHeaderSpace = DandelionLayout.minTopMargin
            + proportionalOffset
            + (dandelionLargeHeight * 0.72)
            + DandelionLayout.dandelionToTextSpacing
        #else
        let promptHeaderSpace = DandelionLayout.minTopMargin
            + proportionalOffset
            + (dandelionLargeHeight * 0.80)
            + DandelionLayout.dandelionToTextSpacing
        #endif
#if os(macOS)
        let writingHeaderSpace = DandelionLayout.minTopMargin
            + (dandelionSmallHeight * 0.10)
            + DandelionLayout.dandelionToTextSpacing
#else
        let writingHeaderSpace = DandelionLayout.minTopMargin
            + (dandelionSmallHeight * 0.40)
            + DandelionLayout.dandelionToTextSpacing
#endif
        let headerSpaceHeight = isReleasing
            ? writingHeaderSpace
            : (isPromptState || viewModel.isDandelionReturning ? promptHeaderSpace : writingHeaderSpace)

#if os(macOS)
        let releaseDandelionVisualBottom = releaseDandelionTop + (dandelionLargeHeight * 0.72)
#else
        let releaseDandelionVisualBottom = releaseDandelionTop + (dandelionLargeHeight * 0.92)
#endif
        let promptMessageTopPadding = releaseDandelionVisualBottom + DandelionLayout.dandelionToTextSpacing

        return LayoutMetrics(
            safeAreaTop: safeAreaTop,
            safeAreaBottom: safeAreaBottom,
            fullScreenSize: fullScreenSize,
            dandelionHeight: dandelionHeight,
            dandelionTopPadding: dandelionTopPadding,
            releaseDandelionTop: releaseDandelionTop,
            effectiveDandelionTopPadding: effectiveDandelionTopPadding,
            headerSpaceHeight: headerSpaceHeight,
            promptMessageTopPadding: promptMessageTopPadding
        )
    }

    private func contentView(in size: CGSize, safeAreaBottom: CGFloat, safeAreaTop: CGFloat, headerSpaceHeight: CGFloat, fullScreenSize: CGSize) -> some View {
#if os(macOS)
        // On macOS, bring buttons up closer to center for better balance
        let promptBottomPadding = max(size.height * 0.15, 100)
#else
        let promptBottomPadding = safeAreaBottom + DandelionSpacing.lg
#endif
        _ = safeAreaTop

        return ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Space for dandelion (rendered separately as overlay)
                Color.clear
                    .frame(height: headerSpaceHeight)
                    .animation(suppressPromptLayoutAnimation ? nil : .easeInOut(duration: 1.6), value: isPromptState)

                headerView(in: size)
                    .animation(suppressPromptLayoutAnimation ? nil : .easeInOut(duration: 1.6), value: isPromptState)

                if isPromptState && isPromptVisible && !hasUsedPromptTap && viewModel.availablePromptCount > 1 {
                    promptTapCallout
                        .padding(.top, DandelionSpacing.sm)
                        .transition(.opacity)
                }

                if isPromptState {
                    Spacer(minLength: 0)
                } else {
                    writingArea(fullScreenSize: fullScreenSize)
                        .transition(.opacity)
                }
            }

            if isPromptVisible {
                promptButtons
                    .padding(.bottom, promptBottomPadding)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
#if os(macOS)
        .background(Self.debugShowReleaseLayers ? Color.blue.opacity(0.08) : Color.clear)
#endif
        .safeAreaInset(edge: .top, spacing: 0) {
#if os(iOS)
            HStack {
                historyButton
                Spacer()
                settingsButton
            }
            .padding(.horizontal, DandelionSpacing.screenEdge)
            .padding(.top, UIDevice.current.userInterfaceIdiom == .pad ? 65 : 0)
            .frame(height: UIDevice.current.userInterfaceIdiom == .pad ? 42 : 32)
#else
            Color.clear.frame(height: 0)
#endif
        }
    }

    private var historyButton: some View {
        Button {
            onShowHistory()
        } label: {
            Image(systemName: "calendar")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(theme.secondary)
        }
        .accessibilityLabel("Release history")
        .accessibilityHint("View your calendar of past releases")
        .opacity(isPromptVisible ? 0.8 : 0)
        .animation(DandelionAnimation.gentle, value: isPromptVisible)
        .allowsHitTesting(isPromptVisible)
    }

    private var settingsButton: some View {
        Button {
            isSettingsPresented = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(theme.secondary)
        }
        .accessibilityLabel("Settings")
        .accessibilityHint("Customize prompts, appearance, sounds, and more")
        .opacity(isPromptVisible ? 0.8 : 0)
        .animation(DandelionAnimation.gentle, value: isPromptVisible)
        .allowsHitTesting(isPromptVisible)
    }

    @ViewBuilder
    private func headerView(in size: CGSize) -> some View {
        // Just the prompt text - dandelion is rendered separately as a persistent element
        // Spacing above text is handled by headerSpaceHeight from DandelionLayout
        if let prompt = viewModel.currentPrompt {
            let promptMatchId = "promptText-\(prompt.id)"
            WordAnimatedTextView(
                text: prompt.text,
                font: isPromptState ? .dandelionTitle : .dandelionCaption,
                uiFont: isPromptState ? .dandelionTitle : .dandelionCaption,
                textColor: isPromptState ? theme.text : theme.secondary,
                lineWidth: max(
                    0,
                    size.width - ((isPromptState ? DandelionSpacing.xl : DandelionSpacing.screenEdge) * 2)
                ),
                isAnimating: false,
                maxLines: isPromptState ? nil : 1,
                lineBreakMode: isPromptState ? .byWordWrapping : .byTruncatingTail,
                layoutIDPrefix: prompt.id
            )
            .matchedGeometryEffect(id: promptMatchId, in: promptNamespace)
            .padding(.horizontal, isPromptState ? DandelionSpacing.xl : DandelionSpacing.screenEdge)
            .padding(.top, isPromptState ? 0 : DandelionSpacing.xs)
            .opacity(isPromptHeaderVisible && !isReleasing ? (isPromptVisible ? promptOpacity : 1) : 0)
            .animation(.easeInOut(duration: 1.0), value: isReleasing)
            .contentShape(Rectangle())
            .onTapGesture {
                guard isPromptState, viewModel.availablePromptCount > 1 else { return }
#if !os(macOS)
                HapticsService.shared.tap()
#endif
                viewModel.newPrompt()
                hasUsedPromptTap = true
            }
            .accessibilityHint(isPromptState && viewModel.availablePromptCount > 1 ? "Tap to see another prompt" : "")
        }
    }

    private var promptButtons: some View {
        VStack(spacing: DandelionSpacing.md) {
            beginWritingButton
        }
    }

    private var beginWritingButton: some View {
        Button("Begin Writing") {
#if !os(macOS)
            HapticsService.shared.tap()
#endif
            viewModel.startWriting()
        }
        .buttonStyle(.dandelion)
        .accessibilityHint("Start writing your thoughts")
    }

    private var promptTapCallout: some View {
        Text("Hint: tap the prompt to see another")
            .font(.system(size: 13, design: .serif))
            .foregroundColor(theme.secondary)
            .multilineTextAlignment(.center)
            .accessibilityLabel("Tap the prompt to see another")
    }

    private func writingArea(fullScreenSize: CGSize) -> some View {
        VStack(spacing: 0) {
            // Text editor fills available space
            GeometryReader { geometry in
                let baseHorizontalPadding = DandelionSpacing.screenEdge - 5
#if os(macOS)
                let horizontalPadding = max(
                    baseHorizontalPadding,
                    (geometry.size.width - DandelionLayout.maxWritingWidth) / 2
                )
#else
                let horizontalPadding = baseHorizontalPadding
#endif
                let size = geometry.size
                let lineWidth = geometry.size.width - (horizontalPadding * 2)
                let overlayVisibleHeight = isReleasing
                    ? (releaseVisibleHeight > 0 ? releaseVisibleHeight : lastWritingAreaHeight)
                    : size.height

                ZStack(alignment: .topLeading) {
                    // Auto-scrolling text editor (hidden when releasing)
#if os(macOS)
                    AutoScrollingTextEditor(
                        text: $viewModel.writtenText,
                        font: .dandelionWriting,
                        textColor: PlatformColor(theme.text),
                        isEditable: isWriting,
                        scrollbarKnobStyle: appearance.colorScheme == .light ? .dark : .automatic,
                        isVisible: showWrittenText,
                        shouldBeFocused: $isTextEditorFocused,
                        scrollOffset: $textScrollOffset
                    )
                    .frame(width: lineWidth,
                           height: geometry.size.height)
                    .opacity(showWrittenText ? 1 : 0)
                    // Disable animations on state changes to ensure instant hide (matching iOS)
                    .animation(nil, value: showWrittenText)
                    .animation(nil, value: viewModel.writingState)
                    .transaction { transaction in
                        if isReleasing {
                            transaction.animation = nil
                        }
                    }
                    .zIndex(0)
#else
                    AutoScrollingTextEditor(
                        text: $viewModel.writtenText,
                        font: .dandelionWriting,
                        textColor: PlatformColor(theme.text),
                        isEditable: isWriting,
                        scrollbarKnobStyle: appearance.colorScheme == .light ? .dark : .automatic,
                        shouldBeFocused: $isTextEditorFocused,
                        scrollOffset: $textScrollOffset
                    )
                    .frame(width: lineWidth,
                           height: geometry.size.height)
                    .opacity(showWrittenText ? 1 : 0)
                    .animation(nil, value: showWrittenText)
                    .animation(nil, value: viewModel.writingState)
                    .transaction { transaction in
                        if isReleasing {
                            transaction.animation = nil
                        }
                    }
#endif

                    // Animatable text overlay - starts at the same position as the text editor
                    // Top padding matches UITextView's textContainerInset when unscrolled,
                    // but reduces to 0 when scrolled (since scrolled text appears at y=0)
                    // Note: On macOS, this is rendered as a top-level overlay (macOSAnimatedTextOverlay)
                    // to ensure it floats above the dandelion
#if os(iOS)
                    AnimatableTextView(
                        text: showAnimatedText ? releaseTextSnapshot : viewModel.writtenText,
                        font: .dandelionWriting,
                        uiFont: .dandelionWriting,
                        textColor: theme.text,
                        lineWidth: lineWidth,
                        isAnimating: animateLetters,
                        fadeOutTrigger: fadeOutLetters,
                        screenSize: fullScreenSize,
                        visibleHeight: overlayVisibleHeight,
                        scrollOffset: capturedScrollOffset
                    )
                    .padding(.top, max(0, 8 - capturedScrollOffset))
                    // Clip mask that starts at view bounds, then expands upward to release characters
                    // Uses gradient at top edge for smooth fade-in rather than hard clip
                    .mask(
                        GeometryReader { geo in
                            VStack(spacing: 0) {
                                // Soft gradient edge at top
                                LinearGradient(
                                    colors: [.clear, .black],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 0.3)
                                // Solid visible area below
                                Rectangle()
                            }
                            .frame(height: geo.size.height + releaseClipOffset)
                            .offset(y: -releaseClipOffset)
                        }
                    )
                    .opacity(showAnimatedText ? 1 : 0)
                    .allowsHitTesting(false)
                    .zIndex(1)
#endif
                }
                .padding(.horizontal, horizontalPadding)
                .opacity((isWriting || isReleasing) ? 1 : 0)
                .animation(nil, value: isWriting)
#if os(macOS)
                .background(Self.debugShowReleaseLayers ? Color.green.opacity(0.08) : Color.clear)
                .overlay(alignment: .topLeading) {
                    if Self.debugShowReleaseMetrics {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("overlayVisibleHeight: \(Int(overlayVisibleHeight))")
                            Text("releaseVisibleHeight: \(Int(releaseVisibleHeight))")
                            Text("lastWritingAreaHeight: \(Int(lastWritingAreaHeight))")
                            Text("capturedScrollOffset: \(Int(capturedScrollOffset))")
                            Text("textScrollOffset: \(Int(textScrollOffset))")
                            Text("lineWidth: \(Int(lineWidth))")
                        }
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .padding(6)
                        .background(Color.black.opacity(0.2))
                        .foregroundColor(.white)
                        .padding(.top, 4)
                        .padding(.leading, 4)
                    }
                }
#endif

                Color.clear
                    .onAppear {
                        guard !isReleasing else { return }
                        let height = size.height
                        DispatchQueue.main.async {
                            if lastWritingAreaHeight != height {
                                lastWritingAreaHeight = height
                            }
                        }
                    }
                    .onChange(of: size.height) { _, newValue in
                        guard !isReleasing else { return }
                        DispatchQueue.main.async {
                            if lastWritingAreaHeight != newValue {
                                lastWritingAreaHeight = newValue
                            }
                        }
                    }
                    .onChange(of: isReleasing) { _, newValue in
                        if WritingViewModel.debugReleaseFlow {
                            debugLog(
                                "[ReleaseFlow] writingArea size=\(size.height) last=\(lastWritingAreaHeight) releasing=\(newValue)"
                            )
                        }
                    }
            }

        }
        .padding(.top, DandelionSpacing.sm)
        .opacity((isWriting || isReleasing) ? 1 : 0)
        .allowsHitTesting(isWriting)
        .animation(nil, value: viewModel.writingState)
    }

    private func fadeInPrompt() {
        if WritingViewModel.debugReleaseFlow {
            debugLog(
                "[ReleaseFlow] fadeInPrompt id=\(viewModel.currentPrompt?.id ?? "nil") initial=\(!hasShownInitialPrompt)"
            )
        }
        if !hasShownInitialPrompt {
            promptOpacity = 1
            hasShownInitialPrompt = true
            return
        }
        promptOpacity = 0
        withAnimation(.easeIn(duration: 0.6)) {
            promptOpacity = 1
        }
    }

    private func setupReleaseTracking() {
        viewModel.onReleaseTriggered = { [modelContext] wordCount in
            let service = ReleaseHistoryService(modelContext: modelContext)
            service.recordRelease(wordCount: wordCount)
        }
    }

    private func checkHintResetForReturningUser() {
        // Only check once per app session
        guard !Self.hasCheckedHintReset else { return }
        Self.hasCheckedHintReset = true

        let manager = HintResetManager()
        if manager.checkAndResetHintsIfNeeded() {
            // Sync @AppStorage properties with UserDefaults changes
            hasUsedPromptTap = false
            hasSeenLetGoHint = false
        }
    }

    private func syncCustomPrompts() {
        let activeCustomPrompts = customPrompts
            .filter { $0.isActive }
            .map { WritingPrompt(id: $0.id.uuidString, text: $0.text) }

        // Get disabled default prompt IDs from SwiftData (synced via CloudKit)
        let disabledIds = Set(
            defaultPromptSettings
                .filter { !$0.isEnabled }
                .map { $0.promptId }
        )

        viewModel.refreshPrompts(
            customPrompts: activeCustomPrompts,
            disabledDefaultIds: disabledIds,
            isPremiumUnlocked: premium.isBloomUnlocked
        )
    }

    private func handleAmbientSound(for state: WritingState) {
        guard isActive else {
            ambientSound.stop()
            return
        }
        guard premium.isBloomUnlocked else {
            debugLog("WritingView: ambient stop (not premium)")
            ambientSound.stop()
            return
        }
        if ambientSound.isPreviewing {
            debugLog("WritingView: ambient skip (previewing)")
            return
        }
        guard ambientSound.isEnabled else {
            debugLog("WritingView: ambient stop (disabled)")
            ambientSound.stop()
            return
        }

        switch state {
        case .writing:
            debugLog("WritingView: ambient start (writing)")
            ambientSound.start()
        case .releasing:
            debugLog("WritingView: ambient start (releasing)")
            ambientSound.start()
        case .prompt:
            if ambientSound.isFadingOut {
                debugLog("WritingView: ambient skip stop (fading out)")
                return
            }
            debugLog("WritingView: ambient stop (prompt)")
            ambientSound.stop()
        case .complete:
            debugLog("WritingView: ambient fadeOut (complete)")
            ambientSound.fadeOut(duration: 1.8)
        }
    }

    private func handleDandelionWindAnimation(for state: WritingState) {
        // Cancel any pending animation task
        dandelionWindAnimationTask?.cancel()
        dandelionWindAnimationTask = nil

        switch state {
        case .writing:
            // Delay stopping the wind animation until the position animation completes
            dandelionWindAnimationTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                isDandelionWindAnimating = false
            }
        case .prompt, .releasing, .complete:
            // Immediately resume wind animation for other states
            isDandelionWindAnimating = true
        }
    }

    // MARK: - Bottom Bar

    private func bottomBar(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Blow indicator - appears above the bar (only when writing)
            if viewModel.showBlowIndicator && isWriting {
                blowIndicator
                    .padding(.bottom, DandelionSpacing.md)
            }

            // Bottom bar with persistent background
            ZStack {
                // Background stays visible during release
                theme.background
                    .ignoresSafeArea(edges: .bottom)

                // Content hides during release
                HStack(spacing: DandelionSpacing.md) {
                    ambientToggleButton

                    Spacer()

                    // Info button to show hint
                    Button {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showLetGoHint = true
                        }
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 20))
                            .foregroundColor(theme.secondary)
                    }
                    .accessibilityLabel("Help")
                    .accessibilityHint("Learn how to release your writing")
#if os(macOS)
                    .buttonStyle(.plain)
#endif

                    // Manual release button
                    Button {
                        // Capture scroll offset BEFORE dismissing keyboard to prevent text shift
                        capturedScrollOffset = textScrollOffset
                        isTextEditorFocused = false
                        viewModel.manualRelease()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "wind")
                                .font(.system(size: 15))
                            Text("Let Go")
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                        }
                        .foregroundColor(theme.background)
                        .padding(.horizontal, DandelionSpacing.md)
                        .padding(.vertical, DandelionSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(theme.primary)
                        )
                    }
                    .accessibilityLabel("Let Go")
                    .accessibilityHint("Release your writing and watch it drift away like dandelion seeds")
                    .accessibilityAddTraits(viewModel.canRelease ? [] : .isStaticText)
                    .disabled(!viewModel.canRelease)
                    .opacity(viewModel.canRelease ? 1.0 : 0.5)
#if os(macOS)
                    .buttonStyle(.plain)
#endif
                }
                .padding(.horizontal, DandelionSpacing.md)
                .opacity(isWriting ? 1 : 0)
            }
            .frame(height: 56) // Fixed height for consistent layout
            .padding(.bottom, isTextEditorFocused ? DandelionSpacing.sm : bottomInset)
            .animation(nil, value: isTextEditorFocused)
        }
        .opacity((isWriting || isReleasing) ? 1 : 0)
        .allowsHitTesting(isWriting)
    }

    // MARK: - Microphone Status

    @ViewBuilder
    private var microphoneStatusView: some View {
        if !viewModel.blowDetection.permissionDetermined {
            // Prompt to enable blow detection
            Button {
                Task {
                    await viewModel.requestMicrophonePermission()
                }
            } label: {
                HStack(spacing: DandelionSpacing.xs) {
                    Image(systemName: "mic")
                    Text("Enable blow")
                }
                .font(.dandelionCaption)
                .foregroundColor(theme.secondary)
            }
        } else if viewModel.blowDetection.hasPermission {
            // Instruction text with mic indicator
            HStack(spacing: 4) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 11))
                    .foregroundColor(theme.accent)
                Text("Or blow gently into your microphone")
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondary)
            }
        } else {
            // Permission denied - offer Settings link
            HStack(spacing: 4) {
                Image(systemName: "mic.slash")
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondary)
                Text("Microphone access is off.")
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondary)
                Button("Open Settings") {
                    openAppSettings()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.accent)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Blow Indicator

    private var blowIndicator: some View {
        HStack {
            Image(systemName: "wind")
                .foregroundColor(theme.accent)

            Text("Keep blowing...")
                .font(.dandelionSecondary)
                .foregroundColor(theme.text)
        }
        .padding(.horizontal, DandelionSpacing.lg)
        .padding(.vertical, DandelionSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.primary.opacity(0.5))
        )
        .transition(.opacity.combined(with: .scale))
        .accessibilityLabel("Keep blowing into the microphone to release your writing")
    }

    // MARK: - Let Go Hint Overlay

    private var letGoHintOverlay: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.height < 700

            ZStack {
                // Dimmed background
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showLetGoHint = false
                        }
                    }

                // Hint card
                VStack(spacing: isCompact ? DandelionSpacing.lg : DandelionSpacing.xl) {
                    // Title - large and prominent
                    Text("When you're ready to let go")
                        .font(.system(size: isCompact ? 22 : 26, weight: .medium, design: .serif))
                        .foregroundColor(theme.text)
                        .multilineTextAlignment(.center)

                    // Instructions
                    VStack(alignment: .leading, spacing: isCompact ? DandelionSpacing.md : DandelionSpacing.lg) {
                        // Tap instruction
                        HStack(alignment: .firstTextBaseline, spacing: DandelionSpacing.sm) {
                            Image(systemName: "hand.tap")
                                .font(.system(size: 16))
                                .foregroundColor(theme.accent)
                                .frame(width: 24)
                            Text("Tap the **Let Go** button")
                                .font(.system(size: isCompact ? 16 : 18, design: .serif))
                                .foregroundColor(theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Blow instruction with mic permission below
                        VStack(alignment: .leading, spacing: DandelionSpacing.sm) {
                            HStack(alignment: .firstTextBaseline, spacing: DandelionSpacing.sm) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(theme.accent)
                                    .frame(width: 24)
                                Text("Or blow gently into your microphone")
                                    .font(.system(size: isCompact ? 16 : 18, design: .serif))
                                    .foregroundColor(theme.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            // Mic permission - smaller, secondary text
                            if viewModel.blowDetection.permissionDetermined && !viewModel.blowDetection.hasPermission {
                                HStack(spacing: 4) {
                                    Text("Microphone is off.")
                                        .foregroundColor(theme.secondary)
                                    Button("Open Settings") {
                                        openAppSettings()
                                    }
                                    .foregroundColor(theme.accent)
                                    .buttonStyle(.plain)
                                }
                                .font(.system(size: 12, design: .serif))
                                .padding(.leading, 24 + DandelionSpacing.sm)
                            } else if !viewModel.blowDetection.permissionDetermined {
                                HStack(spacing: 4) {
                                    Text("Requires microphone.")
                                        .foregroundColor(theme.secondary)
                                    Button("Enable") {
                                        Task {
                                            await viewModel.requestMicrophonePermission()
                                        }
                                    }
                                    .foregroundColor(theme.accent)
                                    .buttonStyle(.plain)
                                }
                                .font(.system(size: 12, design: .serif))
                                .padding(.leading, 24 + DandelionSpacing.sm)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: isCompact ? DandelionSpacing.md : DandelionSpacing.lg) {
                        Text("Your words will scatter like dandelion seeds.")
                            .font(.system(size: 14, design: .serif))
                            .foregroundColor(theme.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showLetGoHint = false
                            }
                        } label: {
                            Text("Got it")
                                .font(.system(size: 16, weight: .medium, design: .serif))
                                .foregroundColor(theme.background)
                                .padding(.horizontal, DandelionSpacing.xl)
                                .padding(.vertical, DandelionSpacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(theme.primary)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Got it")
                        .accessibilityHint("Dismiss this help dialog")
                    }
                }
                .padding(.horizontal, isCompact ? DandelionSpacing.md : DandelionSpacing.xl)
                .padding(.vertical, isCompact ? DandelionSpacing.xl : DandelionSpacing.xxl)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(theme.card)
                )
                .frame(maxWidth: 420)
                .padding(.horizontal, DandelionSpacing.lg)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .accessibilityLabel("How to let go of your writing")
            }
        }
        .transition(.opacity)
    }

    // MARK: - Dandelion Illustration

    private func dandelionIllustration(height: CGFloat) -> some View {
        // Use Color.clear as layout placeholder, with DandelionBloomView overlaid
        // This allows seeds to fly upward beyond the layout bounds without clipping
        let overflowHeight: CGFloat = 500
        let hasReleaseAnimation = viewModel.writingState == .releasing
            || !viewModel.detachedSeedTimes.isEmpty
            || viewModel.seedRestoreStartTime != nil
        let isWindAnimating = appearance.isWindAnimationAllowed && !reduceMotion
            ? (isDandelionWindAnimating || hasReleaseAnimation)
            : hasReleaseAnimation
        return Color.clear
            .frame(height: height)
            .overlay(alignment: .bottom) {
                DandelionBloomView(
                    seedCount: viewModel.dandelionSeedCount,
                    style: appearance.style,
                    detachedSeedTimes: viewModel.detachedSeedTimes,
                    seedRestoreStartTime: viewModel.seedRestoreStartTime,
                    seedRestoreDuration: viewModel.seedRestoreDuration,
                    topOverflow: overflowHeight,
                    isAnimating: isActive && isWindAnimating
                )
                .id(appearance.style)
                .frame(height: height + overflowHeight)
#if os(macOS)
                .background(Self.debugShowDandelionLayer ? Color.red.opacity(0.12) : Color.clear)
#endif
            }
            .allowsHitTesting(false)
    }

    private func openAppSettings() {
#if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
#elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            openURL(url)
        }
#endif
    }

    private var ambientToggleButton: some View {
        Button {
            if premium.isBloomUnlocked {
                ambientSound.isEnabled.toggle()
                handleAmbientSound(for: viewModel.writingState)
            } else {
                showBloomPaywall = true
            }
        } label: {
            Image(systemName: ambientSound.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(premium.isBloomUnlocked ? theme.secondary : theme.subtle)
        }
        .accessibilityLabel("Ambient sound")
        .accessibilityValue(ambientSound.isEnabled ? "On" : "Off")
        .accessibilityHint(premium.isBloomUnlocked ? "Toggle calming background sounds" : "Unlock Dandelion Bloom for ambient sounds")
        .buttonStyle(.plain)
    }

}

#Preview {
    WritingView()
        .environment(PremiumManager.shared)
        .environment(AppearanceManager())
        .environment(AmbientSoundService())
        .modelContainer(for: [Release.self, CustomPrompt.self, DefaultPromptSetting.self], inMemory: true)
}

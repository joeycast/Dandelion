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
    static let privacyHintText = "Your words are never saved or shared. Only release counts and dates stay on your device (and in iCloud if enabled)."

    let topSafeArea: CGFloat
    let bottomSafeArea: CGFloat
    let onShowHistory: () -> Void
    let onSwipeEligibilityChange: (Bool) -> Void
    let isActive: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(AppearanceManager.self) private var appearance
    @Environment(PremiumManager.self) private var premium
    @Environment(AmbientSoundService.self) private var ambientSound
    @Environment(ReminderNotificationService.self) private var reminderService
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Release.timestamp) private var allReleases: [Release]
    @Query(sort: \CustomPrompt.createdAt) private var customPrompts: [CustomPrompt]
    @Query private var defaultPromptSettings: [DefaultPromptSetting]
    @State private var viewModel = WritingViewModel()
    @State private var isTextEditorFocused: Bool = false
    @State private var animateLetters: Bool = false
    @State private var promptOpacity: Double = 1
    @State private var mainContentOpacity: Double = 0
    @State private var textScrollOffset: CGFloat = 0
    @State private var capturedScrollOffset: CGFloat = 0
    /// Live frame of the writing editor content (in `writingRoot` space).
    @State private var liveWritingEditorFrame: CGRect = .zero
    /// Frame frozen at release start so letters begin where the written text was.
    @State private var capturedWritingEditorFrame: CGRect = .zero
    @State private var releaseDandelionTopPadding: CGFloat? = nil
    @State private var lastWritingDandelionTopPadding: CGFloat = 0
    @State private var releaseTextSnapshot: String = ""
    @State private var showWrittenText: Bool = true
    @State private var showAnimatedText: Bool = false
    @State private var releaseVisibleHeight: CGFloat = 0
    @State private var lastWritingAreaHeight: CGFloat = 0
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
    @State private var startsSettingsInReminders: Bool = false
    @State private var showLetGoHint: Bool = false
    @State private var isReminderNudgePresented: Bool = false
    @State private var pendingReminderNudgeAfterRegrowth: Bool = false
    @AppStorage("globalCountEnabled") private var globalCountEnabled: Bool = true
    @AppStorage("hasSeenLetGoHint") private var hasSeenLetGoHint: Bool = false
    @AppStorage("hasUsedPromptTap") private var hasUsedPromptTap: Bool = false
    private static var hasCheckedHintReset = false
    @Namespace private var promptNamespace
    @State private var hasShownInitialPrompt: Bool = false
    @State private var isDandelionWindAnimating: Bool = true
    @State private var dandelionWindAnimationTask: Task<Void, Never>?
    @State private var globalReleaseCounts: GlobalReleaseCounts?
    @State private var globalReleaseService = GlobalReleaseCountService()
    @State private var globalCountsPollingTask: Task<Void, Never>?

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
            Task {
                await refreshGlobalCounts(forceRefresh: false)
#if os(iOS)
                await reminderService.rescheduleIfNeeded(releases: allReleases)
#endif
            }
            updateGlobalCountsPolling()
        }
        .onDisappear {
            globalCountsPollingTask?.cancel()
            globalCountsPollingTask = nil
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
            updateGlobalCountsPolling()
        }
        .onChange(of: scenePhase) { _, newValue in
            updateGlobalCountsPolling()
            guard newValue == .active else { return }
            Task {
                await refreshGlobalCounts(forceRefresh: false)
#if os(iOS)
                await reminderService.rescheduleIfNeeded(releases: allReleases)
#endif
            }
        }
        .onChange(of: isPromptVisible) { _, isVisible in
            updateGlobalCountsPolling()
            guard isVisible else { return }
            Task {
                await refreshGlobalCounts(forceRefresh: false)
            }
        }
        .onChange(of: globalCountEnabled) { _, _ in
            updateGlobalCountsPolling()
            Task {
                await refreshGlobalCounts(forceRefresh: false)
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
            SettingsView(startsInReminders: startsSettingsInReminders)
                .preferredColorScheme(appearance.colorScheme)
        }
#if os(iOS)
        .alert("Daily reminders", isPresented: $isReminderNudgePresented) {
            Button("Not Now", role: .cancel) {}
            Button("Enable") {
                Task {
                    let granted = await reminderService.requestPermission()
                    debugLog("[ReminderNudge] alert enable tapped granted=\(granted)")
                    guard granted else { return }
                    await reminderService.setEnabled(true, releases: allReleases)
                    startsSettingsInReminders = true
                    isSettingsPresented = true
                }
            }
        } message: {
            Text("Would you like a daily reminder to take a moment and release?")
        }
#endif
        .onChange(of: isSettingsPresented) { _, isPresented in
            if !isPresented {
                // Reload prompt configuration when settings closes
                syncCustomPrompts()
                startsSettingsInReminders = false
            }
        }
        .onChange(of: isReminderNudgePresented) { _, isPresented in
            debugLog("[ReminderNudge] isReminderNudgePresented=\(isPresented)")
        }
        .overlay {
            if showLetGoHint {
                WritingLetGoHintView(
                    permissionDetermined: viewModel.blowDetection.permissionDetermined,
                    hasMicrophonePermission: viewModel.blowDetection.hasPermission,
                    onRequestMicrophone: {
                        Task { await viewModel.requestMicrophonePermission() }
                    },
                    onDismiss: {
                        showLetGoHint = false
                    }
                )
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
                            WritingBottomBar(
                                isWriting: isWriting,
                                isReleasing: isReleasing,
                                isTextEditorFocused: isTextEditorFocused,
                                bottomInset: layout.safeAreaBottom,
                                canRelease: viewModel.canRelease,
                                showBlowIndicator: viewModel.showBlowIndicator,
                                blowDetection: viewModel.blowDetection,
                                onShowHelp: {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        showLetGoHint = true
                                    }
                                },
                                onLetGo: {
                                    // Freeze editor geometry before keyboard dismiss shifts layout.
                                    capturedScrollOffset = textScrollOffset
                                    if liveWritingEditorFrame != .zero {
                                        capturedWritingEditorFrame = liveWritingEditorFrame
                                    }
                                    isTextEditorFocused = false
                                    viewModel.manualRelease()
                                },
                                onAmbientChanged: {
                                    handleAmbientSound(for: viewModel.writingState)
                                },
                                onShowPaywall: {
                                    showBloomPaywall = true
                                },
                                onRequestMicrophone: {
                                    Task { await viewModel.requestMicrophonePermission() }
                                }
                            )
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

                // Floating release text sits above the dandelion so glyphs aren't clipped.
                if showAnimatedText {
                    releaseAnimatedTextOverlay(fullScreenSize: layout.fullScreenSize)
                        .zIndex(2)
                }

                // Release message overlay
                if isReleasing {
                    releaseMessageOverlay(layout: layout)
                        .zIndex(3)
                }
            }
            .opacity(mainContentOpacity)
        }
        .coordinateSpace(name: "writingRoot")
        .onPreferenceChange(WritingEditorFrameKey.self) { frame in
            // Keep tracking while writing so release can freeze the exact on-screen origin.
            guard viewModel.writingState == .writing, frame.width > 0, frame.height > 0 else { return }
            liveWritingEditorFrame = frame
        }
        .onChange(of: viewModel.writingState) { _, newValue in
            if WritingViewModel.debugReleaseFlow {
                debugLog(
                    "[ReleaseFlow] writingState -> \(newValue) prompt=\(viewModel.currentPrompt?.id ?? "nil")"
                )
            }
            if newValue == .releasing {
                logReleaseTiming("state=releasing")
                // Capture scroll/frame while layout still matches the written text.
                // Manual Let Go already frozen these before keyboard dismiss; blow still has focus here.
#if os(macOS)
                capturedScrollOffset = textScrollOffset
                if liveWritingEditorFrame != .zero {
                    capturedWritingEditorFrame = liveWritingEditorFrame
                }
#else
                if isTextEditorFocused {
                    capturedScrollOffset = textScrollOffset
                    if liveWritingEditorFrame != .zero {
                        capturedWritingEditorFrame = liveWritingEditorFrame
                    }
                } else if capturedWritingEditorFrame == .zero, liveWritingEditorFrame != .zero {
                    capturedWritingEditorFrame = liveWritingEditorFrame
                }
#endif
                releaseDandelionTopPadding = lastWritingDandelionTopPadding
                releaseTextSnapshot = viewModel.writtenText
                showAnimatedText = false
                fadeOutLetters = false
                releaseVisibleHeight = lastWritingAreaHeight
                if WritingViewModel.debugReleaseFlow {
                    debugLog(
                        "[ReleaseFlow] release heights snapshot area=\(lastWritingAreaHeight) visible=\(releaseVisibleHeight) frame=\(capturedWritingEditorFrame)"
                    )
                }
                // Note: Seed detachment is now handled in triggerRelease() for atomic state update
                // Show animated text and hide written text together for smooth handoff
                showAnimatedText = true
                animateLetters = true
                logReleaseTiming("animatedText=visible")
                showWrittenText = false
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
                if newValue != .writing {
                    capturedWritingEditorFrame = .zero
                }
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

    /// Release letters rendered above the dandelion layer so they aren't clipped underneath it.
    /// Positioned from the frozen editor frame so letters start where the written text was
    /// (no jump when the keyboard dismisses or layout reflows).
    @ViewBuilder
    private func releaseAnimatedTextOverlay(fullScreenSize: CGSize) -> some View {
        let frame = capturedWritingEditorFrame
        let topOverflowForAnimation: CGFloat = 500
        // Buffer so the last visible line isn't clipped at descenders.
        let overlayVisibleHeight = max(
            frame.height,
            (releaseVisibleHeight > 0 ? releaseVisibleHeight : lastWritingAreaHeight) + 30
        )
        let lineWidth = max(frame.width, 1)

        if frame.width > 0, frame.height > 0 {
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
                horizontalOffset: 0
            )
            // Match UITextView textContainerInset top (8) accounting for scroll.
            .padding(.top, max(0, 8 - capturedScrollOffset))
            .frame(width: frame.width, alignment: .topLeading)
            // Canvas draws resting glyphs at y = topOverflow; place view so that maps to editor top.
            .offset(x: frame.minX, y: frame.minY - topOverflowForAnimation)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
        }
    }

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
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let topBarHeight: CGFloat = isPad ? 44 : 32
        // Keep controls clear of iPad window chrome while preserving a correct hit-test region.
        let topBarOffset: CGFloat = isPad ? max(44, safeAreaTop + 6) : 0
#endif

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
            VStack(spacing: 0) {
                Spacer(minLength: topBarOffset)
                HStack {
                    historyButton
                    Spacer()
                    settingsButton
                }
                .padding(.horizontal, DandelionSpacing.screenEdge)
                .frame(height: topBarHeight)
            }
            .frame(height: topBarOffset + topBarHeight)
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
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
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
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
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

            if globalCountEnabled {
                globalReleaseCountView
                    .padding(.top, DandelionSpacing.sm)
            }
        }
    }

    private var globalReleaseCountView: some View {
        ZStack(alignment: .top) {
            if shouldShowGlobalReleaseCountText, let counts = globalReleaseCounts {
                let countString = OdometerCountText.formatted(counts.today)
                let timesWord = counts.today == 1 ? "time" : "times"
                Text(globalReleaseCountMessage(countString: countString, timesWord: timesWord))
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(theme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DandelionSpacing.xxxl)
            }
        }
        .frame(height: 34, alignment: .top)
        .opacity(shouldShowGlobalReleaseCountText ? 1 : 0)
        .animation(.easeInOut(duration: 1.0), value: shouldShowGlobalReleaseCountText)
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
                let lineWidth = geometry.size.width - (horizontalPadding * 2)

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
                    // Measure the editor itself (not the padded outer container) so release
                    // letters inherit the same horizontal inset as the written text.
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: WritingEditorFrameKey.self,
                                value: geo.frame(in: .named("writingRoot"))
                            )
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
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: WritingEditorFrameKey.self,
                                value: geo.frame(in: .named("writingRoot"))
                            )
                        }
                    }
#endif

                    // Release letter animation is rendered in `releaseAnimatedTextOverlay`
                    // above the dandelion so floating words aren't clipped underneath it.
                }
                .padding(.horizontal, horizontalPadding)
                .opacity((isWriting || isReleasing) ? 1 : 0)
                .animation(nil, value: isWriting)
#if os(macOS)
                .background(Self.debugShowReleaseLayers ? Color.green.opacity(0.08) : Color.clear)
                .overlay(alignment: .topLeading) {
                    if Self.debugShowReleaseMetrics {
                        VStack(alignment: .leading, spacing: 4) {
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
                        let height = geometry.size.height
                        if abs(lastWritingAreaHeight - height) > 0.5 {
                            lastWritingAreaHeight = height
                        }
                    }
                    .onChange(of: geometry.size.height) { _, newValue in
                        guard !isReleasing else { return }
                        if abs(lastWritingAreaHeight - newValue) > 0.5 {
                            lastWritingAreaHeight = newValue
                        }
                    }
                    .onChange(of: isReleasing) { _, newValue in
                        if WritingViewModel.debugReleaseFlow {
                            debugLog(
                                "[ReleaseFlow] writingArea size=\(geometry.size.height) last=\(lastWritingAreaHeight) releasing=\(newValue)"
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
            Task { @MainActor in
                handleReleaseTriggered(wordCount: wordCount, modelContext: modelContext)
            }
        }
        viewModel.onRegrowthCompleted = {
            handleRegrowthCompleted()
        }
    }

    private func handleRegrowthCompleted() {
#if os(iOS)
        debugLog(
            "[ReminderNudge] handleRegrowthCompleted pending=\(pendingReminderNudgeAfterRegrowth) detached=\(viewModel.detachedSeedTimes.count)"
        )
        guard pendingReminderNudgeAfterRegrowth else { return }
        pendingReminderNudgeAfterRegrowth = false
        reminderService.markPostFirstReleaseNudgeShown()
        isReminderNudgePresented = true
#endif
    }

    private func queueReminderNudgeAfterRegrowthIfNeeded() {
#if os(iOS)
        let regrowthAlreadyComplete = viewModel.seedRestoreStartTime == nil && viewModel.detachedSeedTimes.isEmpty
        debugLog(
            "[ReminderNudge] queueDecision regrowthAlreadyComplete=\(regrowthAlreadyComplete) detached=\(viewModel.detachedSeedTimes.count) seedRestoreStartTimeNil=\(viewModel.seedRestoreStartTime == nil)"
        )
        if regrowthAlreadyComplete {
            reminderService.markPostFirstReleaseNudgeShown()
            isReminderNudgePresented = true
        } else {
            pendingReminderNudgeAfterRegrowth = true
            debugLog("[ReminderNudge] queued until regrowth complete")
        }
#endif
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

    @MainActor
    private func handleReleaseTriggered(wordCount: Int, modelContext: ModelContext) {
        let service = ReleaseHistoryService(modelContext: modelContext)
        service.recordRelease(wordCount: wordCount)

#if os(iOS)
        Task {
            await reminderService.handleReleaseRecorded()
        }

        Task {
            debugLog("[ReminderNudge] evaluating nudge after release")
            await reminderService.refreshPermissionStatus()
            let shouldPresent = reminderService.shouldPresentPostFirstReleaseNudge
            debugLog(
                "[ReminderNudge] post-permission shouldPresent=\(shouldPresent) permissionState=\(reminderService.permissionState) hasShown=\(reminderService.hasShownPostFirstReleaseNudge)"
            )
            guard shouldPresent else { return }
            debugLog("[ReminderNudge] eligible; queuing/presenting")
            queueReminderNudgeAfterRegrowthIfNeeded()
        }
#endif

        guard globalCountEnabled else { return }

        if let cached = globalReleaseCounts {
            let updated = cached.incremented(wordCount: wordCount)
            withAnimation(.easeInOut(duration: 0.25)) {
                globalReleaseCounts = updated
            }
        }

        Task {
            await globalReleaseService.incrementCountsIfEnabled(globalCountEnabled, wordCount: wordCount)
            try? await Task.sleep(for: .seconds(3))
            let refreshed = await globalReleaseService.loadCounts(forceRefresh: true)
            await MainActor.run {
                guard globalCountEnabled else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    globalReleaseCounts = refreshed
                }
            }
        }
    }

    private var shouldPollGlobalCounts: Bool {
        globalCountEnabled && isActive && isPromptVisible && scenePhase == .active
    }

    private func updateGlobalCountsPolling() {
        globalCountsPollingTask?.cancel()
        globalCountsPollingTask = nil
        guard shouldPollGlobalCounts else { return }

        globalCountsPollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(45))
                guard !Task.isCancelled else { return }
                let refreshed = await globalReleaseService.loadCounts(forceRefresh: true)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        globalReleaseCounts = refreshed
                    }
                }
            }
        }
    }

    private func refreshGlobalCounts(forceRefresh: Bool) async {
        guard globalCountEnabled else {
            withAnimation(.easeInOut(duration: 0.2)) {
                globalReleaseCounts = nil
            }
            return
        }

        let loaded = await globalReleaseService.loadCounts(forceRefresh: forceRefresh)
        withAnimation(.easeInOut(duration: 0.25)) {
            globalReleaseCounts = loaded
        }
    }

    private func globalReleaseCountMessage(countString: String, timesWord: String) -> String {
        if hasReleasedToday {
            return "People around the world have let go \(countString) \(timesWord) today."
        }
        return "People around the world have let go \(countString) \(timesWord) today. Join them."
    }

    private var hasReleasedToday: Bool {
        allReleases.contains { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var shouldShowGlobalReleaseCountText: Bool {
        globalCountEnabled && (globalReleaseCounts?.today ?? 0) > 0
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
}

/// Reports the writing editor's on-screen frame for release-letter alignment.
private struct WritingEditorFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 0, next.height > 0 {
            value = next
        }
    }
}

#Preview {
    WritingView()
        .environment(PremiumManager.shared)
        .environment(AppearanceManager())
        .environment(AmbientSoundService())
        .modelContainer(for: [Release.self, CustomPrompt.self, DefaultPromptSetting.self], inMemory: true)
}

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
    @State private var showBloomPaywall: Bool = false
    @State private var isSettingsPresented: Bool = false
    @State private var showLetGoHint: Bool = false
    @AppStorage("hasSeenLetGoHint") private var hasSeenLetGoHint: Bool = false
    @Namespace private var promptNamespace
    @State private var hasShownInitialPrompt: Bool = false
    @State private var isDandelionWindAnimating: Bool = true
    @State private var dandelionWindAnimationTask: Task<Void, Never>?

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
            let safeAreaTop = topSafeArea
            let safeAreaBottom = max(bottomSafeArea, geometry.safeAreaInsets.bottom)
            let fullScreenSize = CGSize(
                width: geometry.size.width,
                height: geometry.size.height + safeAreaTop + safeAreaBottom
            )

            // Dandelion sizing
            let dandelionSmallHeight = DandelionLayout.dandelionSmallHeight
            let dandelionLargeHeight = DandelionLayout.dandelionLargeHeight
            // Size: large on prompt, small during writing, grows back when returning
            let dandelionHeight: CGFloat = (isPromptState || viewModel.isDandelionReturning)
                ? dandelionLargeHeight
                : dandelionSmallHeight

            // Dandelion positioning
            let dandelionBaseTop = safeAreaTop + DandelionLayout.minTopMargin
            let proportionalOffset = DandelionLayout.proportionalOffset(screenHeight: geometry.size.height)
            // Prompt/release: dandelion moves down with proportional offset for visual centering
            // Writing: dandelion stays at base position (closer to top)
            let dandelionTopPadding: CGFloat = (isPromptState || viewModel.isDandelionReturning || isReleasing)
                ? dandelionBaseTop + proportionalOffset
                : dandelionBaseTop
            let releaseDandelionTop = dandelionBaseTop + proportionalOffset
            let effectiveDandelionTopPadding = isReleasing
                ? (releaseDandelionTopPadding ?? lastWritingDandelionTopPadding)
                : dandelionTopPadding

            // Content header space - position text directly below the VISUAL dandelion
            // Prompt state: large dandelion, use 0.80 ratio (slightly above stem end)
            let promptHeaderSpace = DandelionLayout.minTopMargin
                + proportionalOffset
                + (dandelionLargeHeight * 0.80)
                + DandelionLayout.dandelionToTextSpacing
            // Writing state: small dandelion, use 0.50 ratio (tighter to head)
            let writingHeaderSpace = DandelionLayout.minTopMargin
                + (dandelionSmallHeight * 0.40)
                + DandelionLayout.dandelionToTextSpacing
            let headerSpaceHeight = (isPromptState || viewModel.isDandelionReturning) ? promptHeaderSpace : writingHeaderSpace

            // Release message position - uses 0.92 ratio (perfect per user feedback)
            let releaseDandelionVisualBottom = releaseDandelionTop + (dandelionLargeHeight * 0.92)
            let promptMessageTopPadding = releaseDandelionVisualBottom + DandelionLayout.dandelionToTextSpacing

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
                        safeAreaBottom: safeAreaBottom,
                        safeAreaTop: safeAreaTop,
                        headerSpaceHeight: headerSpaceHeight,
                        fullScreenSize: fullScreenSize
                    )
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            if isWriting || isReleasing {
                                bottomBar(bottomInset: safeAreaBottom)
                                    // Animate in normally, but disappear instantly to avoid
                                    // clipping through the appearing prompt buttons
                                    .transition(.asymmetric(
                                        insertion: .opacity,
                                        removal: .identity
                                    ))
                            }
                        }

                    // Single persistent dandelion - lives above all content, animates size and position
                    VStack {
                        dandelionIllustration(height: dandelionHeight)
                        Spacer()
                    }
                    .padding(.top, effectiveDandelionTopPadding)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                    .animation(.easeInOut(duration: 1.2), value: isPromptState)
                    .animation(.easeInOut(duration: 1.2), value: dandelionHeight)
                    .animation(.easeInOut(duration: 1.2), value: viewModel.isDandelionReturning)
                    .animation(.easeInOut(duration: 1.2), value: releaseDandelionTopPadding)
                    .animation(nil, value: viewModel.writingState)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                    // Release message overlay
                    if isReleasing {
                        ReleaseMessageView(
                            releaseMessage: viewModel.currentReleaseMessage.text,
                            messageTopPadding: promptMessageTopPadding,
                            onMessageAppear: {
                                withAnimation(.easeInOut(duration: 1.2)) {
                                    releaseDandelionTopPadding = releaseDandelionTop
                                }
                                viewModel.startDandelionReturn()
                            },
                            onMessageFadeStart: {
                                viewModel.startSeedRestoreNow()
                            },
                            onComplete: {}
                        )
                        .ignoresSafeArea()
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
                }
                .opacity(mainContentOpacity)
            }
            .onChange(of: viewModel.writingState) { _, newValue in
                if WritingViewModel.debugReleaseFlow {
                    debugLog(
                        "[ReleaseFlow] writingState -> \(newValue) prompt=\(viewModel.currentPrompt?.id ?? "nil")"
                    )
                }
                if newValue == .releasing {
                    // Capture scroll offset only if keyboard is still up (blow-triggered release).
                    // For manual release, the button action already captured it before dismissing keyboard.
                    if isTextEditorFocused {
                        capturedScrollOffset = textScrollOffset
                    }
                    releaseDandelionTopPadding = lastWritingDandelionTopPadding
                    releaseTextSnapshot = viewModel.writtenText
                    showAnimatedText = true
                    releaseVisibleHeight = lastWritingAreaHeight
                    if WritingViewModel.debugReleaseFlow {
                        debugLog(
                            "[ReleaseFlow] release heights snapshot area=\(lastWritingAreaHeight) visible=\(releaseVisibleHeight)"
                        )
                    }
                    showWrittenText = false
                    viewModel.beginReleaseDetachment()
                    animateLetters = true
                    // Start with clip at bounds, then animate it open to release characters upward
                    releaseClipOffset = 0
                    withAnimation(.easeInOut(duration: 2.0)) {
                        releaseClipOffset = 200
                    }
                }
                // Update focus state after releasing check (so we can detect if keyboard was up)
                isTextEditorFocused = newValue == .writing
                if newValue == .writing {
                    lastWritingDandelionTopPadding = dandelionTopPadding
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
                    releaseDandelionTopPadding = nil
                    showWrittenText = true
                    showAnimatedText = false
                    releaseVisibleHeight = 0
                    releaseClipOffset = 0
                }
                // Don't fade prompt on state change - let the prompt ID change handler do it
                // This prevents double-animation when transitioning from release to prompt
                if newValue == .writing {
                    promptOpacity = 1
                }
                onSwipeEligibilityChange(isPromptVisible)
            }
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

    private func contentView(in size: CGSize, safeAreaBottom: CGFloat, safeAreaTop: CGFloat, headerSpaceHeight: CGFloat, fullScreenSize: CGSize) -> some View {
        let promptBottomPadding = safeAreaBottom + DandelionSpacing.lg
        _ = safeAreaTop

        return ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Space for dandelion (rendered separately as overlay)
                Color.clear
                    .frame(height: headerSpaceHeight)
                    .animation(.easeInOut(duration: 1.6), value: isPromptState)

                headerView(in: size)
                    .animation(.easeInOut(duration: 1.6), value: isPromptState)

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
        .safeAreaInset(edge: .top, spacing: 0) {
#if os(iOS)
            HStack {
                historyButton
                Spacer()
                settingsButton
            }
            .padding(.horizontal, DandelionSpacing.screenEdge)
            .frame(height: 32)
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
        }
    }

    private var promptButtons: some View {
        VStack(spacing: DandelionSpacing.md) {
            // Only show shuffle button if there are 2+ prompts to cycle through
            if viewModel.availablePromptCount > 1 {
                Button("New Prompt") {
                    HapticsService.shared.tap()
                    viewModel.newPrompt()
                }
                .font(.dandelionCaption)
                .foregroundColor(theme.secondary)
            }

            Button("Begin Writing") {
                HapticsService.shared.tap()
                viewModel.startWriting()
            }
            .buttonStyle(.dandelion)
        }
    }

    private func writingArea(fullScreenSize: CGSize) -> some View {
        VStack(spacing: 0) {
            // Text editor fills available space
            GeometryReader { geometry in
                let horizontalPadding = DandelionSpacing.screenEdge - 5
                let size = geometry.size
                let lineWidth = geometry.size.width - (horizontalPadding * 2)
                let overlayVisibleHeight = isReleasing
                    ? (releaseVisibleHeight > 0 ? releaseVisibleHeight : lastWritingAreaHeight)
                    : size.height

                ZStack(alignment: .topLeading) {
                    // Auto-scrolling text editor (hidden when releasing)
                    AutoScrollingTextEditor(
                        text: $viewModel.writtenText,
                        font: .dandelionWriting,
                        textColor: PlatformColor(theme.text),
                        isEditable: isWriting,
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

                    // Animatable text overlay - starts at the same position as the text editor
                    // Top padding matches UITextView's textContainerInset when unscrolled,
                    // but reduces to 0 when scrolled (since scrolled text appears at y=0)
                    AnimatableTextView(
                        text: showAnimatedText ? releaseTextSnapshot : viewModel.writtenText,
                        font: .dandelionWriting,
                        uiFont: .dandelionWriting,
                        textColor: theme.text,
                        lineWidth: lineWidth,
                        isAnimating: animateLetters,
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
                }
                .padding(.horizontal, horizontalPadding)
                .opacity((isWriting || isReleasing) ? 1 : 0)
                .animation(nil, value: isWriting)

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
                    .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
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
                    .disabled(!viewModel.canRelease)
                    .opacity(viewModel.canRelease ? 1.0 : 0.5)
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
                Text("Tap Let Go, or simply blow to release")
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondary)
            }
        } else {
            // Permission denied - no hint needed, button is clear
            EmptyView()
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
    }

    // MARK: - Let Go Hint Overlay

    private var letGoHintOverlay: some View {
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
            VStack(spacing: DandelionSpacing.md) {
                Text("When you're ready to let go")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundColor(theme.text)

                VStack(alignment: .leading, spacing: DandelionSpacing.sm) {
                    HStack(alignment: .top, spacing: DandelionSpacing.sm) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 16))
                            .foregroundColor(theme.accent)
                            .frame(width: 24)
                        Text("Tap the **Let Go** button")
                            .font(.system(size: 16, design: .serif))
                            .foregroundColor(theme.text)
                    }

                    HStack(alignment: .top, spacing: DandelionSpacing.sm) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16))
                            .foregroundColor(theme.accent)
                            .frame(width: 24)
                        Text("Or blow gently into your microphone")
                            .font(.system(size: 16, design: .serif))
                            .foregroundColor(theme.text)
                    }
                }

                Text("Your words will scatter like dandelion seeds.")
                    .font(.system(size: 14, design: .serif))
                    .foregroundColor(theme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, DandelionSpacing.xs)

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
                .padding(.top, DandelionSpacing.sm)
            }
            .padding(DandelionSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.card)
            )
            .padding(.horizontal, DandelionSpacing.xl)
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
            }
            .allowsHitTesting(false)
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
            Image(systemName: ambientSound.isEnabled ? "speaker.wave.2.fill" : "speaker.wave.2")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(premium.isBloomUnlocked ? theme.secondary : theme.subtle)
                .accessibilityLabel("Ambient sound")
        }
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

//
//  WritingView.swift
//  Dandelion
//
//  Main writing experience view
//

import SwiftUI
import SwiftData
import UIKit

struct WritingView: View {
    let topSafeArea: CGFloat
    let bottomSafeArea: CGFloat
    let onShowHistory: () -> Void
    let onSwipeEligibilityChange: (Bool) -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WritingViewModel()
    @State private var isTextEditorFocused: Bool = false
    @State private var animateLetters: Bool = false
    @State private var promptOpacity: Double = 1
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
    @Namespace private var promptNamespace

    init(
        topSafeArea: CGFloat = 0,
        bottomSafeArea: CGFloat = 0,
        onShowHistory: @escaping () -> Void = {},
        onSwipeEligibilityChange: @escaping (Bool) -> Void = { _ in }
    ) {
        self.topSafeArea = topSafeArea
        self.bottomSafeArea = bottomSafeArea
        self.onShowHistory = onShowHistory
        self.onSwipeEligibilityChange = onSwipeEligibilityChange
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
            let dandelionSmallHeight: CGFloat = 80
            let dandelionLargeHeight: CGFloat = 220
            // Size: large on prompt, small during writing, grows back when returning
            let dandelionHeight: CGFloat = (isPrompt || viewModel.isDandelionReturning) ? dandelionLargeHeight : dandelionSmallHeight

            // Dandelion positioning - base position below safe area
            let dandelionBaseTop = safeAreaTop + DandelionSpacing.md
            // Extra offset to center dandelion on prompt/return/release states
            let nonReleaseOffset: CGFloat = (isPrompt || viewModel.isDandelionReturning)
                ? max(0, geometry.size.height * 0.08)
                : 0
            let releaseOffset: CGFloat = max(0, geometry.size.height * 0.08)
            let dandelionOffset: CGFloat = isReleasing ? releaseOffset : nonReleaseOffset
            let dandelionTopPadding = dandelionBaseTop + dandelionOffset
            let releaseDandelionTop = dandelionBaseTop + releaseOffset
            let effectiveDandelionTopPadding = isReleasing
                ? (releaseDandelionTopPadding ?? lastWritingDandelionTopPadding)
                : dandelionTopPadding

            // Content header space - writing prompt sits just below the dandelion
            let contentHeaderSpace = dandelionBaseTop + dandelionSmallHeight - DandelionSpacing.xxxl
            let promptLift = DandelionSpacing.xxl
            let headerSpaceHeight = isPrompt
                ? max(0, dandelionBaseTop + dandelionLargeHeight - promptLift)
                : max(0, contentHeaderSpace)
            let promptMessageTopPadding = (dandelionBaseTop + max(0, geometry.size.height * 0.08))
                + dandelionLargeHeight
                - promptLift
                + DandelionSpacing.lg
                + DandelionSpacing.xl

            ZStack {
                // Background
                Color.dandelionBackground
                    .ignoresSafeArea()
                    .onTapGesture {
                        isTextEditorFocused = false
                    }

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
                        }
                    }

                // Single persistent dandelion - lives above all content, animates size and position
                VStack {
                    dandelionIllustration(height: dandelionHeight)
                    Spacer()
                }
                .padding(.top, effectiveDandelionTopPadding)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .animation(.easeInOut(duration: 1.2), value: isPrompt)
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
            .onChange(of: viewModel.writingState) { _, newValue in
                if WritingViewModel.debugReleaseFlow {
                    debugLog("[ReleaseFlow] writingState -> \(newValue)")
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
                }
                if newValue == .prompt || newValue == .complete || newValue == .writing {
                    animateLetters = false
                    releaseDandelionTopPadding = nil
                    showWrittenText = true
                    showAnimatedText = false
                    releaseVisibleHeight = 0
                    releaseClipOffset = 0
                }
                if newValue == .prompt || newValue == .complete {
                    fadeInPrompt()
                } else if newValue == .writing {
                    promptOpacity = 1
                }
                onSwipeEligibilityChange(isPrompt)
            }
        }
        .animation(DandelionAnimation.slow, value: viewModel.writingState)
        .onAppear {
            if isPrompt {
                fadeInPrompt()
            }
            setupReleaseTracking()
            onSwipeEligibilityChange(isPrompt)
        }
        .onChange(of: viewModel.currentPrompt.id) { _, _ in
            if isPrompt {
                fadeInPrompt()
            }
        }
    }

    private var isPrompt: Bool {
        viewModel.writingState == .prompt || viewModel.writingState == .complete
    }

    private var isWriting: Bool {
        viewModel.writingState == .writing
    }

    private var isReleasing: Bool {
        viewModel.writingState == .releasing
    }

    private func contentView(in size: CGSize, safeAreaBottom: CGFloat, safeAreaTop: CGFloat, headerSpaceHeight: CGFloat, fullScreenSize: CGSize) -> some View {
        let promptBottomPadding = safeAreaBottom + DandelionSpacing.lg
        _ = safeAreaTop

        return ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Space for dandelion (rendered separately as overlay)
                Color.clear
                    .frame(height: headerSpaceHeight)
                    .animation(.easeInOut(duration: 1.6), value: isPrompt)

                headerView(in: size)
                    .animation(.easeInOut(duration: 1.6), value: isPrompt)

                if isPrompt {
                    Spacer(minLength: 0)
                } else {
                    writingArea(fullScreenSize: fullScreenSize)
                        .transition(.opacity)
                }
            }

            if isPrompt {
                promptButtons
                    .padding(.bottom, promptBottomPadding)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                historyButton
                Spacer()
            }
            .padding(.horizontal, DandelionSpacing.screenEdge)
            .frame(height: 32)
        }
    }

    private var historyButton: some View {
        Button {
            onShowHistory()
        } label: {
            Image(systemName: "calendar")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.dandelionSecondary)
        }
        .opacity(isPrompt ? 0.8 : 0)
        .animation(DandelionAnimation.gentle, value: isPrompt)
        .allowsHitTesting(isPrompt)
    }

    private func headerView(in size: CGSize) -> some View {
        // Just the prompt text - dandelion is rendered separately as a persistent element
        let promptMatchId = "promptText-\(viewModel.currentPrompt.id)"
        return WordAnimatedTextView(
            text: viewModel.currentPrompt.text,
            font: isPrompt ? .dandelionTitle : .dandelionCaption,
            uiFont: isPrompt ? .dandelionTitle : .dandelionCaption,
            textColor: isPrompt ? .dandelionText : .dandelionSecondary,
            lineWidth: max(
                0,
                size.width - ((isPrompt ? DandelionSpacing.xl : DandelionSpacing.screenEdge) * 2)
            ),
            isAnimating: false,
            maxLines: isPrompt ? nil : 1,
            lineBreakMode: isPrompt ? .byWordWrapping : .byTruncatingTail,
            layoutIDPrefix: viewModel.currentPrompt.id
        )
        .matchedGeometryEffect(id: promptMatchId, in: promptNamespace)
        .padding(.horizontal, isPrompt ? DandelionSpacing.xl : DandelionSpacing.screenEdge)
        .padding(.top, isPrompt ? DandelionSpacing.lg : DandelionSpacing.xs)
        .opacity(isReleasing ? 0 : (isPrompt ? promptOpacity : 1))
        .animation(.easeInOut(duration: 1.0), value: isReleasing)
    }

    private var promptButtons: some View {
        VStack(spacing: DandelionSpacing.md) {
            Button("New Prompt") {
                HapticsService.shared.tap()
                viewModel.currentPrompt = PromptsManager().randomPrompt()
            }
            .font(.dandelionCaption)
            .foregroundColor(.dandelionSecondary)

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
                        textColor: PlatformColor(Color.dandelionText),
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
                        textColor: .dandelionText,
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
                Color.dandelionBackground
                    .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
                    .ignoresSafeArea(edges: .bottom)

                // Content hides during release
                HStack(spacing: DandelionSpacing.lg) {
                    // Microphone permission / blow instruction
                    microphoneStatusView

                    Spacer()

                    // Manual release button
                    Button {
                        // Capture scroll offset BEFORE dismissing keyboard to prevent text shift
                        capturedScrollOffset = textScrollOffset
                        isTextEditorFocused = false
                        viewModel.manualRelease()
                    } label: {
                        HStack(spacing: DandelionSpacing.sm) {
                            Image(systemName: "wind")
                            Text("Let Go")
                        }
                    }
                    .buttonStyle(.dandelion)
                    .disabled(!viewModel.canRelease)
                    .opacity(viewModel.canRelease ? 1.0 : 0.5)
                }
                .padding(.horizontal, DandelionSpacing.screenEdge)
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
            Button {
                Task {
                    await viewModel.requestMicrophonePermission()
                }
            } label: {
                HStack(spacing: DandelionSpacing.xs) {
                    Image(systemName: "mic")
                    Text("Enable Blow")
                }
                .font(.dandelionCaption)
                .foregroundColor(.dandelionSecondary)
            }
        } else if viewModel.blowDetection.hasPermission {
            HStack(spacing: DandelionSpacing.xs) {
                Image(systemName: "mic.fill")
                    .foregroundColor(.dandelionAccent)
                Text("Blow to release")
                    .font(.dandelionCaption)
                    .foregroundColor(.dandelionSecondary)
            }
        } else {
            // Permission denied - no indicator needed
            EmptyView()
        }
    }

    // MARK: - Blow Indicator

    private var blowIndicator: some View {
        HStack {
            Image(systemName: "wind")
                .foregroundColor(.dandelionAccent)

            Text("Keep blowing...")
                .font(.dandelionSecondary)
                .foregroundColor(.dandelionText)
        }
        .padding(.horizontal, DandelionSpacing.lg)
        .padding(.vertical, DandelionSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dandelionPrimary.opacity(0.5))
        )
        .transition(.opacity.combined(with: .scale))
    }

    // MARK: - Dandelion Illustration

    private func dandelionIllustration(height: CGFloat) -> some View {
        // Use Color.clear as layout placeholder, with DandelionBloomView overlaid
        // This allows seeds to fly upward beyond the layout bounds without clipping
        let overflowHeight: CGFloat = 500
        return Color.clear
            .frame(height: height)
            .overlay(alignment: .bottom) {
                DandelionBloomView(
                    seedCount: viewModel.dandelionSeedCount,
                    detachedSeedTimes: viewModel.detachedSeedTimes,
                    seedRestoreStartTime: viewModel.seedRestoreStartTime,
                    seedRestoreDuration: viewModel.seedRestoreDuration,
                    topOverflow: overflowHeight
                )
                .frame(height: height + overflowHeight)
            }
            .allowsHitTesting(false)
    }

}

#Preview {
    WritingView()
}

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
    @State private var writingAreaSize: CGSize = .zero
    @State private var writingAreaTop: CGFloat = 0
    @State private var textScrollOffset: CGFloat = 0
    @State private var capturedScrollOffset: CGFloat = 0
    @State private var capturedWritingAreaTop: CGFloat = 0
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
            // Extra offset to center dandelion on prompt/return states
            let dandelionPromptOffset: CGFloat = (isPrompt || viewModel.isDandelionReturning) ? max(0, geometry.size.height * 0.08) : 0
            let dandelionTopPadding = dandelionBaseTop + dandelionPromptOffset

            // Content header space - writing prompt sits just below the dandelion
            let contentHeaderSpace = dandelionBaseTop + dandelionSmallHeight - DandelionSpacing.xxxl
            let promptLift = DandelionSpacing.xxl
            let headerSpaceHeight = isPrompt
                ? max(0, dandelionBaseTop + dandelionLargeHeight - promptLift)
                : max(0, contentHeaderSpace)

            ZStack {
                // Background
                Color.dandelionBackground
                    .ignoresSafeArea()
                    .onTapGesture {
                        isTextEditorFocused = false
                    }

                // Content (prompt text, writing area, buttons) - fades in/out
                contentView(in: geometry.size, safeAreaBottom: safeAreaBottom, safeAreaTop: safeAreaTop, headerSpaceHeight: headerSpaceHeight)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if isWriting || isReleasing {
                            bottomBar(bottomInset: safeAreaBottom)
                        }
                    }

                // Animatable text overlay - positioned to match writing area exactly
                let textEditorHorizontalPadding = DandelionSpacing.screenEdge - 5
                let textContainerInset: CGFloat = 8
                let visibleInset = max(0, textContainerInset - capturedScrollOffset)
                let fineTuning: CGFloat = 2.25
                let footerHeight: CGFloat = 56 + safeAreaBottom

                // Calculate writing area top position directly from layout values:
                // contentHeaderSpace (includes safeArea + dandelion)
                // + DandelionSpacing.xs (headerView top padding in writing mode)
                // + prompt text height
                // + DandelionSpacing.sm (writingArea top padding)
                let promptTextHeight = UIFont.dandelionCaption.lineHeight
                let calculatedWritingAreaTop = contentHeaderSpace + DandelionSpacing.xs + promptTextHeight + DandelionSpacing.sm

                AnimatableTextView(
                    text: viewModel.writtenText,
                    font: .dandelionWriting,
                    uiFont: .dandelionWriting,
                    textColor: .dandelionText,
                    lineWidth: geometry.size.width - (textEditorHorizontalPadding * 2),
                    isAnimating: animateLetters,
                    screenSize: fullScreenSize,
                    visibleHeight: writingAreaSize.height,
                    scrollOffset: capturedScrollOffset
                )
                .padding(.horizontal, textEditorHorizontalPadding)
                .padding(.top, calculatedWritingAreaTop + visibleInset + fineTuning)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .mask {
                    VStack(spacing: 0) {
                        Color.white
                        Color.clear
                            .frame(height: footerHeight)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                }
                .opacity(isReleasing ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: isReleasing)
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // Single persistent dandelion - lives above all content, animates size and position
                VStack {
                    dandelionIllustration(height: dandelionHeight)
                    Spacer()
                }
                .padding(.top, dandelionTopPadding)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .animation(.easeInOut(duration: 1.2), value: isPrompt)
                .animation(.easeInOut(duration: 1.2), value: dandelionHeight)
                .animation(.easeInOut(duration: 1.2), value: viewModel.isDandelionReturning)
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // Release message overlay
                if isReleasing {
                    ReleaseMessageView(
                        releaseMessage: viewModel.currentReleaseMessage.text,
                        onMessageAppear: {
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
        }
        .coordinateSpace(name: "writingSpace")
        .onPreferenceChange(WritingAreaTopKey.self) { writingAreaTop = $0 }
        .animation(DandelionAnimation.slow, value: viewModel.writingState)
        .onAppear {
            if isPrompt {
                fadeInPrompt()
            }
            setupReleaseTracking()
            onSwipeEligibilityChange(isPrompt)
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { _ in }
                .onEnded { _ in },
            including: isPrompt ? .none : .gesture
        )
        .onChange(of: viewModel.writingState) { _, newValue in
            if WritingViewModel.debugReleaseFlow {
                debugLog("[ReleaseFlow] writingState -> \(newValue)")
            }
            isTextEditorFocused = newValue == .writing
            if newValue == .releasing {
                // Capture positions at the moment of release
                capturedScrollOffset = textScrollOffset
                capturedWritingAreaTop = writingAreaTop
                debugLog("[ReleaseFlow] capturedWritingAreaTop = \(writingAreaTop)")
                viewModel.beginReleaseDetachment()
                animateLetters = true
            }
            if newValue == .writing || newValue == .prompt || newValue == .complete {
                animateLetters = false
            }
            if newValue == .prompt || newValue == .complete {
                fadeInPrompt()
            } else if newValue == .writing {
                promptOpacity = 1
            }
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

    private func contentView(in size: CGSize, safeAreaBottom: CGFloat, safeAreaTop: CGFloat, headerSpaceHeight: CGFloat) -> some View {
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
                    writingArea
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

    private var writingArea: some View {
        VStack(spacing: 0) {
            // Text editor fills available space
            GeometryReader { geometry in
                let horizontalPadding = DandelionSpacing.screenEdge - 5
                let size = geometry.size
                let lineWidth = geometry.size.width - (horizontalPadding * 2)

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
                    .opacity(isReleasing ? 0 : 1)
                    .animation(.easeInOut(duration: 0.25), value: isReleasing)

                }
                .padding(.horizontal, horizontalPadding)
                .opacity(isWriting ? 1 : 0)
                .animation(nil, value: isWriting)
                .onAppear {
                    writingAreaSize = size
                }
                .onChange(of: size) { _, newValue in
                    writingAreaSize = newValue
                }
            }
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: WritingAreaTopKey.self,
                            value: proxy.frame(in: .named("writingSpace")).minY
                        )
                }
            )

        }
        .padding(.top, DandelionSpacing.sm)
        .opacity((isWriting || isReleasing) ? 1 : 0)
        .allowsHitTesting(isWriting)
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

private struct WritingAreaTopKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    WritingView()
}

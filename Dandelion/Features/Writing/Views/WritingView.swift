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
    @State private var textScrollOffset: CGFloat = 0
    @State private var capturedScrollOffset: CGFloat = 0
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
            let topInset = topSafeArea + DandelionSpacing.md
            let fullScreenSize = CGSize(
                width: geometry.size.width,
                height: geometry.size.height + topSafeArea + bottomSafeArea
            )
            ZStack {
                // Background
                Color.dandelionBackground
                    .ignoresSafeArea()
                    .onTapGesture {
                        isTextEditorFocused = false
                    }

                contentView(
                    in: geometry.size,
                    safeAreaBottom: bottomSafeArea,
                    safeAreaTop: topInset
                )

                // Animatable text overlay
                if isReleasing {
                    let textEditorHorizontalPadding = DandelionSpacing.screenEdge - 5
                    // Calculate how much of the textContainerInset is still visible (not scrolled off)
                    let textContainerInset: CGFloat = 8
                    let visibleInset = max(0, textContainerInset - capturedScrollOffset)
                    let fineTuning: CGFloat = 2.25
                    // Height of header area (dandelion + prompt)
                    let headerHeight = topInset + DandelionSpacing.sm + 80 + DandelionSpacing.xs + UIFont.dandelionCaption.lineHeight + DandelionSpacing.sm
                    // Footer height (matches bottomBar fixed height)
                    let footerHeight: CGFloat = 56

                    // Layer 1: The animating text (underneath the masks)
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
                    .padding(.top, headerHeight + visibleInset + fineTuning)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)

                    // Layer 2: Header mask - covers text that extends into header area
                    VStack {
                        Color.dandelionBackground
                            .frame(height: headerHeight)
                        Spacer()
                    }
                    .allowsHitTesting(false)

                    // Layer 3: Footer mask - covers text that extends into footer area
                    VStack {
                        Spacer()
                        Color.dandelionBackground
                            .frame(height: footerHeight + bottomSafeArea)
                    }
                    .allowsHitTesting(false)

                    // Layer 4: Dandelion on top of masks (so seeds can animate over everything)
                    VStack {
                        Color.clear
                            .frame(height: topInset + DandelionSpacing.sm)
                        dandelionIllustration(height: 80)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }

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
                    .offset(y: -topSafeArea)
                    .onAppear {
                        if WritingViewModel.debugReleaseFlow {
                            debugLog("[ReleaseFlow] ReleaseMessageView onAppear")
                        }
                        // Start detachment + letter animation in sync
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            viewModel.beginReleaseDetachment()
                            animateLetters = true
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
                // Capture scroll offset at the moment of release
                capturedScrollOffset = textScrollOffset
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

    private func contentView(in size: CGSize, safeAreaBottom: CGFloat, safeAreaTop: CGFloat) -> some View {
        let topSpacerHeight = safeAreaTop + (isPrompt ? max(0, size.height * 0.1) : 0)
        let promptBottomPadding = safeAreaBottom + DandelionSpacing.lg

        return ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: topSpacerHeight)

                headerView(in: size)

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
        .overlay(alignment: .topLeading) {
            historyButton
                .frame(height: 32)
                .padding(.top, safeAreaTop)
                .padding(.leading, DandelionSpacing.screenEdge)
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
        VStack(spacing: isPrompt ? DandelionSpacing.lg : DandelionSpacing.xs) {
            dandelionIllustration(height: (isWriting || (isReleasing && !viewModel.isDandelionReturning)) ? 80 : 220)

            let promptMatchId = "promptText-\(viewModel.currentPrompt.id)"
            WordAnimatedTextView(
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
            .opacity(isReleasing ? 0 : (isPrompt ? promptOpacity : 1))
            .animation(.easeInOut(duration: 1.0), value: isReleasing)
        }
        .offset(y: dandelionReturnOffset(in: size))
        .padding(.top, isPrompt ? 0 : DandelionSpacing.sm)
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
                    .animation(nil, value: isReleasing)

                    // Animatable text overlay - visible when releasing
                    AnimatableTextView(
                        text: viewModel.writtenText,
                        font: .dandelionWriting,
                        uiFont: .dandelionWriting,
                        textColor: .dandelionText,
                        lineWidth: lineWidth,
                        isAnimating: animateLetters,
                        screenSize: geometry.size
                    )
                    .padding(.top, 8)
                    .opacity(isReleasing ? 1 : 0)
                    .animation(nil, value: isReleasing)
                    .allowsHitTesting(false)
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

            // Bottom bar at the bottom (background stays visible during release)
            bottomBar
                .allowsHitTesting(isWriting)
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

    private var bottomBar: some View {
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
        }
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

    private func dandelionReturnOffset(in size: CGSize) -> CGFloat {
        guard viewModel.isDandelionReturning else { return 0 }
        // Position dandelion above the centered release message
        return min(size.height * 0.12, 100)
    }
}

#Preview {
    WritingView()
}

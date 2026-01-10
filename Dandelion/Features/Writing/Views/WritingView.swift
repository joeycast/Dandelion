//
//  WritingView.swift
//  Dandelion
//
//  Main writing experience view
//

import SwiftUI
import UIKit

struct WritingView: View {
    @State private var viewModel = WritingViewModel()
    @State private var isTextEditorFocused: Bool = false
    @State private var animateLetters: Bool = false
    @State private var promptOpacity: Double = 1
    @Namespace private var promptNamespace

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.dandelionBackground
                    .ignoresSafeArea()
                    .onTapGesture {
                        isTextEditorFocused = false
                    }

                contentView(in: geometry.size, safeAreaBottom: geometry.safeAreaInsets.bottom)

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
        }
        .onChange(of: viewModel.writingState) { _, newValue in
            if WritingViewModel.debugReleaseFlow {
                debugLog("[ReleaseFlow] writingState -> \(newValue)")
            }
            isTextEditorFocused = newValue == .writing
            if newValue == .writing || newValue == .prompt || newValue == .complete {
                animateLetters = false
            }
            if newValue == .prompt || newValue == .complete {
                fadeInPrompt()
            } else if newValue == .writing {
                promptOpacity = 1
            }
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

    private func contentView(in size: CGSize, safeAreaBottom: CGFloat) -> some View {
        let topSpacerHeight = isPrompt ? max(0, size.height * 0.1) : 0
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
                let lineWidth = geometry.size.width - (horizontalPadding * 2)

                ZStack(alignment: .topLeading) {
                    // Auto-scrolling text editor (hidden when releasing)
                    AutoScrollingTextEditor(
                        text: $viewModel.writtenText,
                        font: .dandelionWriting,
                        textColor: UIColor(Color.dandelionText),
                        isEditable: isWriting,
                        shouldBeFocused: $isTextEditorFocused
                    )
                    .frame(width: geometry.size.width - (horizontalPadding * 2),
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
            }

            // Bottom bar at the bottom
            bottomBar
                .opacity(isWriting ? 1 : 0)
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

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // Blow indicator - appears above the bar
            if viewModel.showBlowIndicator {
                blowIndicator
                    .padding(.bottom, DandelionSpacing.md)
            }

            // Release buttons bar
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
            .padding(.vertical, DandelionSpacing.md)
            .background(
                Color.dandelionBackground
                    .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
                    .ignoresSafeArea(edges: .bottom)
            )
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

private struct TextEditorFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

#Preview {
    WritingView()
}

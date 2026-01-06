//
//  WritingView.swift
//  Dandelion
//
//  Main writing experience view
//

import SwiftUI

struct WritingView: View {
    @State private var viewModel = WritingViewModel()
    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        ZStack {
            // Background
            Color.dandelionBackground
                .ignoresSafeArea()
                .onTapGesture {
                    isTextEditorFocused = false
                }

            switch viewModel.writingState {
            case .prompt:
                promptView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

            case .writing:
                writingEditorView
                    .transition(.opacity)

            case .releasing:
                ReleaseAnimationView(
                    text: viewModel.writtenText,
                    releaseMessage: viewModel.currentReleaseMessage.text,
                    onComplete: viewModel.releaseComplete
                )
                .transition(.opacity)

            case .complete:
                // This state transitions back to prompt
                EmptyView()
            }
        }
        .animation(DandelionAnimation.slow, value: viewModel.writingState)
    }

    // MARK: - Prompt View

    private var promptView: some View {
        VStack(spacing: DandelionSpacing.xl) {
            Spacer()

            // Dandelion illustration
            dandelionIllustration

            // Prompt text
            Text(viewModel.currentPrompt.text)
                .font(.dandelionTitle)
                .foregroundColor(.dandelionText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DandelionSpacing.xl)

            Spacer()

            // Buttons with reduced spacing
            VStack(spacing: DandelionSpacing.md) {
                // Skip prompt option
                Button("New Prompt") {
                    viewModel.currentPrompt = PromptsManager().randomPrompt()
                }
                .font(.dandelionCaption)
                .foregroundColor(.dandelionSecondary)

                // Begin writing button
                Button("Begin Writing") {
                    viewModel.startWriting()
                }
                .buttonStyle(.dandelion)
            }

//            Spacer()
//                .frame(height: DandelionSpacing.xl)
        }
    }

    // MARK: - Writing Editor View

    private var writingEditorView: some View {
        VStack(spacing: 0) {
            // Top bar with subtle prompt reminder
            HStack {
                Text(viewModel.currentPrompt.text)
                    .font(.dandelionCaption)
                    .foregroundColor(.dandelionSecondary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, DandelionSpacing.screenEdge)
            .padding(.top, DandelionSpacing.md)
            .padding(.bottom, DandelionSpacing.sm)

            // Text editor
            TextEditor(text: $viewModel.writtenText)
                .font(.dandelionWriting)
                .foregroundColor(.dandelionText)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, DandelionSpacing.screenEdge - 5) // Account for TextEditor inset
                .focused($isTextEditorFocused)
                .onAppear {
                    isTextEditorFocused = true
                }

            // Bottom bar with release options
            bottomBar
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

    private var dandelionIllustration: some View {
        DandelionBloomView()
            .frame(height: 200)
    }
}

#Preview {
    WritingView()
}

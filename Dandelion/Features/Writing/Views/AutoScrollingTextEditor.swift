//
//  AutoScrollingTextEditor.swift
//  Dandelion
//
//  A text editor that automatically scrolls to keep the cursor visible.
//

import SwiftUI
import UIKit

struct AutoScrollingTextEditor: UIViewRepresentable {
    @Binding var text: String
    var font: UIFont
    var textColor: UIColor
    var isEditable: Bool
    @Binding var shouldBeFocused: Bool

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(usingTextLayoutManager: false)

        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = .clear
        textView.isEditable = isEditable
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive

        // Disable automatic content inset adjustment
        textView.contentInsetAdjustmentBehavior = .never

        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 5

        textView.text = text
        context.coordinator.textView = textView

        return textView
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        // Accept whatever size SwiftUI proposes - fill the available space
        let width = proposal.width ?? UIScreen.main.bounds.width
        let height = proposal.height ?? 400
        return CGSize(width: width, height: height)
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let coordinator = context.coordinator

        if !coordinator.isProcessingTextChange && textView.text != text {
            textView.text = text
        }

        textView.isEditable = isEditable
        textView.font = font
        textView.textColor = textColor

        if !coordinator.isProcessingFocusChange {
            if shouldBeFocused && !textView.isFirstResponder && isEditable {
                DispatchQueue.main.async {
                    textView.becomeFirstResponder()
                }
            } else if !shouldBeFocused && textView.isFirstResponder {
                textView.resignFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: AutoScrollingTextEditor
        weak var textView: UITextView?
        var isProcessingTextChange = false
        var isProcessingFocusChange = false

        init(_ parent: AutoScrollingTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            isProcessingTextChange = true
            let newText = textView.text ?? ""

            // Scroll after a short delay to ensure layout is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.ensureCursorVisible(textView)
            }

            DispatchQueue.main.async { [weak self] in
                self?.parent.text = newText
                DispatchQueue.main.async {
                    self?.isProcessingTextChange = false
                }
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.ensureCursorVisible(textView)
            }
        }

        private func ensureCursorVisible(_ textView: UITextView) {
            guard let selectedRange = textView.selectedTextRange else { return }

            // Get cursor position
            var caretRect = textView.caretRect(for: selectedRange.end)
            guard !caretRect.isNull && !caretRect.isInfinite else { return }

            // Expand the rect to include some padding
            caretRect.origin.y -= 10
            caretRect.size.height += 60  // Extra space below cursor

            // Use UITextView's built-in method
            textView.scrollRectToVisible(caretRect, animated: false)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isProcessingFocusChange = true
            DispatchQueue.main.async { [weak self] in
                self?.parent.shouldBeFocused = true
                DispatchQueue.main.async {
                    self?.isProcessingFocusChange = false
                }
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isProcessingFocusChange = true
            DispatchQueue.main.async { [weak self] in
                self?.parent.shouldBeFocused = false
                DispatchQueue.main.async {
                    self?.isProcessingFocusChange = false
                }
            }
        }
    }
}

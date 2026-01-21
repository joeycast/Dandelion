//
//  AutoScrollingTextEditor.swift
//  Dandelion
//
//  A text editor that automatically scrolls to keep the cursor visible.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

struct AutoScrollingTextEditor: UIViewRepresentable {
    @Binding var text: String
    var font: PlatformFont
    var textColor: PlatformColor
    var isEditable: Bool
    @Binding var shouldBeFocused: Bool
    @Binding var scrollOffset: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(usingTextLayoutManager: false)

        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = .clear
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.tintColor = textColor

        // Disable automatic content inset adjustment
        textView.contentInsetAdjustmentBehavior = .never

        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 5

        textView.text = text
        context.coordinator.textView = textView

        // Report initial scroll offset
        DispatchQueue.main.async {
            context.coordinator.parent.scrollOffset = textView.contentOffset.y
        }

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
        coordinator.isUpdatingFromSwiftUI = true
        defer { coordinator.isUpdatingFromSwiftUI = false }

        if !coordinator.isProcessingTextChange && textView.text != text {
            textView.text = text
        }

        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.font = font
        textView.textColor = textColor
        textView.tintColor = textColor

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
        var isUpdatingFromSwiftUI = false
        private var pendingScrollUpdate = false
        private var latestScrollOffset: CGFloat = 0

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
                DispatchQueue.main.async { [weak self] in
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
                DispatchQueue.main.async { [weak self] in
                    self?.isProcessingFocusChange = false
                }
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isProcessingFocusChange = true
            DispatchQueue.main.async { [weak self] in
                self?.parent.shouldBeFocused = false
                DispatchQueue.main.async { [weak self] in
                    self?.isProcessingFocusChange = false
                }
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Only update scroll offset when editing is enabled (writing mode)
            guard parent.isEditable else { return }
            latestScrollOffset = scrollView.contentOffset.y
            guard !isUpdatingFromSwiftUI else {
                if !pendingScrollUpdate {
                    pendingScrollUpdate = true
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.pendingScrollUpdate = false
                        if self.parent.scrollOffset != self.latestScrollOffset {
                            self.parent.scrollOffset = self.latestScrollOffset
                        }
                    }
                }
                return
            }
            if parent.scrollOffset != latestScrollOffset {
                parent.scrollOffset = latestScrollOffset
            }
        }
    }
}

#elseif canImport(AppKit)
import AppKit

struct AutoScrollingTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: PlatformFont
    var textColor: PlatformColor
    var isEditable: Bool
    @Binding var shouldBeFocused: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = textColor
        textView.drawsBackground = false
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = false
        textView.textContainerInset = CGSize(width: 0, height: 8)
        textView.textContainer?.lineFragmentPadding = 5
        textView.string = text

        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        context.coordinator.textView = textView
        return scrollView
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        let width = proposal.width ?? 400
        let height = proposal.height ?? 400
        return CGSize(width: width, height: height)
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if !coordinator.isProcessingTextChange && textView.string != text {
            textView.string = text
        }

        textView.isEditable = isEditable
        textView.font = font
        textView.textColor = textColor

        if !coordinator.isProcessingFocusChange {
            if shouldBeFocused && isEditable {
                let isFirstResponder = textView.window?.firstResponder === textView
                if !isFirstResponder {
                    DispatchQueue.main.async {
                        textView.window?.makeFirstResponder(textView)
                    }
                }
            } else if !shouldBeFocused {
                let isFirstResponder = textView.window?.firstResponder === textView
                if isFirstResponder {
                    textView.window?.makeFirstResponder(nil)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AutoScrollingTextEditor
        weak var textView: NSTextView?
        var isProcessingTextChange = false
        var isProcessingFocusChange = false

        init(_ parent: AutoScrollingTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isProcessingTextChange = true
            let newText = textView.string

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.ensureCursorVisible(textView)
            }

            DispatchQueue.main.async { [weak self] in
                self?.parent.text = newText
                DispatchQueue.main.async { [weak self] in
                    self?.isProcessingTextChange = false
                }
            }
        }

        func textDidBeginEditing(_ notification: Notification) {
            isProcessingFocusChange = true
            DispatchQueue.main.async { [weak self] in
                self?.parent.shouldBeFocused = true
                DispatchQueue.main.async { [weak self] in
                    self?.isProcessingFocusChange = false
                }
            }
        }

        func textDidEndEditing(_ notification: Notification) {
            isProcessingFocusChange = true
            DispatchQueue.main.async { [weak self] in
                self?.parent.shouldBeFocused = false
                DispatchQueue.main.async { [weak self] in
                    self?.isProcessingFocusChange = false
                }
            }
        }

        private func ensureCursorVisible(_ textView: NSTextView) {
            let selectedRange = textView.selectedRange()
            textView.scrollRangeToVisible(selectedRange)
        }
    }
}

#elseif canImport(AppKit)
import AppKit

struct AutoScrollingTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: PlatformFont
    var textColor: PlatformColor
    var isEditable: Bool
    @Binding var shouldBeFocused: Bool
    @Binding var scrollOffset: CGFloat

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.textStorage?.setAttributedString(NSAttributedString(string: text))

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView

        DispatchQueue.main.async {
            self.scrollOffset = scrollView.contentView.bounds.origin.y
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.isUpdatingFromSwiftUI = true
        defer { context.coordinator.isUpdatingFromSwiftUI = false }

        if !context.coordinator.isProcessingTextChange && textView.string != text {
            textView.string = text
        }

        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.font = font
        textView.textColor = textColor

        if shouldBeFocused, scrollView.window?.firstResponder != textView, isEditable {
            scrollView.window?.makeFirstResponder(textView)
        } else if !shouldBeFocused, scrollView.window?.firstResponder == textView {
            scrollView.window?.makeFirstResponder(nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AutoScrollingTextEditor
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        var isProcessingTextChange = false
        var isUpdatingFromSwiftUI = false

        init(_ parent: AutoScrollingTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            isProcessingTextChange = true
            let newText = textView.string

            DispatchQueue.main.async { [weak self] in
                self?.parent.text = newText
                self?.isProcessingTextChange = false
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let scrollView else { return }
            DispatchQueue.main.async { [weak self] in
                self?.parent.scrollOffset = scrollView.contentView.bounds.origin.y
            }
        }
    }
}

#endif

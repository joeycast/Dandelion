//
//  MacHistoryWindow.swift
//  Dandelion
//
//  Wrapper view for ReleaseHistoryView in panel window.
//

import SwiftUI

#if os(macOS)
struct MacHistoryWindow: View {
    @Environment(AppearanceManager.self) private var appearance
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ReleaseHistoryView(
            topSafeArea: 0,
            showsTabs: false,
            onNavigateToWriting: {
                dismiss()
            }
        )
        .frame(minWidth: 350, idealWidth: 400, minHeight: 500)
        .background(appearance.theme.background)
    }
}
#endif

//
//  MacInsightsWindow.swift
//  Dandelion
//
//  Wrapper view for InsightsView in panel window.
//

import SwiftUI
import SwiftData

#if os(macOS)
struct MacInsightsWindow: View {
    @Environment(AppearanceManager.self) private var appearance
    @Query(sort: \Release.timestamp) private var releases: [Release]

    var body: some View {
        InsightsView(releases: releases)
            .frame(minWidth: 400, idealWidth: 500, minHeight: 600)
            .background(appearance.theme.background)
    }
}
#endif

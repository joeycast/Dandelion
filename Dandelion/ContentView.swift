//
//  ContentView.swift
//  Dandelion
//
//  Created by Joe Castagnaro on 1/4/26.
//

import SwiftUI

struct ContentView: View {
    @State private var isHistoryPresented: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let topSafeArea = geometry.safeAreaInsets.top
            let bottomSafeArea = geometry.safeAreaInsets.bottom

            WritingView(
                topSafeArea: topSafeArea,
                bottomSafeArea: bottomSafeArea,
                onShowHistory: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isHistoryPresented = true
                    }
                },
                onSwipeEligibilityChange: { _ in }
            )
            .sheet(isPresented: $isHistoryPresented) {
                ReleaseHistoryView(
                    topSafeArea: 0,
                    onNavigateToWriting: {
                        isHistoryPresented = false
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
        .background(Color.dandelionBackground.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
}

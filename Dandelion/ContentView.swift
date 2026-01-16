//
//  ContentView.swift
//  Dandelion
//
//  Created by Joe Castagnaro on 1/4/26.
//

import SwiftUI

private enum RootPage: Hashable {
    case history
    case writing
}

struct ContentView: View {
    @State private var selectedPage: RootPage = .writing
    @State private var canSwipeFromWriting: Bool = true

    var body: some View {
        GeometryReader { geometry in
            let topSafeArea = geometry.safeAreaInsets.top
            let bottomSafeArea = geometry.safeAreaInsets.bottom

            TabView(selection: $selectedPage) {
                ReleaseHistoryView(
                    topSafeArea: topSafeArea,
                    onNavigateToWriting: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedPage = .writing
                        }
                    }
                )
                .tag(RootPage.history)

                WritingView(
                    topSafeArea: topSafeArea,
                    bottomSafeArea: bottomSafeArea,
                    onShowHistory: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedPage = .history
                        }
                    },
                    onSwipeEligibilityChange: { canSwipeFromWriting = $0 }
                )
                .tag(RootPage.writing)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .scrollDisabled(selectedPage == .writing ? !canSwipeFromWriting : false)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .background(Color.dandelionBackground.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
}

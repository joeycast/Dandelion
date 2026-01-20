//
//  ReleaseHistoryView.swift
//  Dandelion
//
//  Main release history screen with year calendar view
//

import SwiftUI
import SwiftData

struct ReleaseHistoryView: View {
    let topSafeArea: CGFloat
    let onNavigateToWriting: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Release.timestamp) private var allReleases: [Release]
    @State private var selectedYear: Int
    @State private var releaseHistoryService: ReleaseHistoryService?
    @State private var releaseDates: Set<Date> = []
    @State private var navigationDirection: Int = 0  // -1 = past, 1 = future

    private let currentYear: Int

    private var earliestYear: Int {
        guard let firstRelease = allReleases.first else {
            return currentYear
        }
        return Calendar.current.component(.year, from: firstRelease.timestamp)
    }

    init(topSafeArea: CGFloat = 0, onNavigateToWriting: @escaping () -> Void = {}) {
        self.topSafeArea = topSafeArea
        self.onNavigateToWriting = onNavigateToWriting
        let year = Calendar.current.component(.year, from: Date())
        _selectedYear = State(initialValue: year)
        currentYear = year
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Calendar grid
                GeometryReader { proxy in
                    YearGridView(
                        year: selectedYear,
                        releaseDates: releaseDates
                    )
                    .padding(.horizontal, DandelionSpacing.md)
                    .padding(.top, DandelionSpacing.md)
                    .id(selectedYear)
                    .transition(yearTransition)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { value in
                            handleYearSwipe(translation: value.translation)
                        }
                )

                // Year navigation at bottom for reachability
                yearNavigationBar
                    .padding(.horizontal, DandelionSpacing.lg)
                    .padding(.vertical, DandelionSpacing.md)
            }
            .background(Color.dandelionBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("History")
                        .font(.dandelionWriting)
                        .foregroundColor(.dandelionPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onNavigateToWriting()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.dandelionSecondary)
                    }
                }
            }
            .toolbarBackground(Color.dandelionBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            releaseHistoryService = ReleaseHistoryService(modelContext: modelContext)
            loadData()
        }
        .onChange(of: allReleases) { _, _ in
            loadData()
        }
    }

    private var yearTransition: AnyTransition {
        let offset: CGFloat = 50
        // Going to past = slide from left, going to future = slide from right
        let direction: CGFloat = navigationDirection < 0 ? -1 : 1
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: offset * direction)),
            removal: .opacity.combined(with: .offset(x: -offset * direction))
        )
    }

    private var canGoBack: Bool {
        selectedYear > earliestYear
    }

    private var canGoForward: Bool {
        selectedYear < currentYear
    }

    private var yearNavigationBar: some View {
        HStack(spacing: DandelionSpacing.lg) {
            // Left chevron or invisible placeholder to maintain layout
            Button {
                navigateToYear(selectedYear - 1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.dandelionPrimary)
            .opacity(canGoBack ? 1 : 0)
            .disabled(!canGoBack)

            Text(verbatim: String(selectedYear))
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundColor(.dandelionPrimary)

            // Right chevron or invisible placeholder to maintain layout
            Button {
                navigateToYear(selectedYear + 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.dandelionPrimary)
            .opacity(canGoForward ? 1 : 0)
            .disabled(!canGoForward)
        }
        .padding(.vertical, DandelionSpacing.sm)
    }

    private func navigateToYear(_ year: Int) {
        navigationDirection = year > selectedYear ? 1 : -1
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedYear = year
            loadData()
        }
    }

    private func loadData() {
        guard let service = releaseHistoryService else { return }
        releaseDates = service.releaseDates(for: selectedYear, from: allReleases)
    }

    private func handleYearSwipe(translation: CGSize) {
        let threshold: CGFloat = 60
        guard abs(translation.width) > abs(translation.height),
              abs(translation.width) > threshold
        else { return }

        if translation.width > 0 && selectedYear > earliestYear {
            navigateToYear(selectedYear - 1)
        } else if translation.width < 0 && selectedYear < currentYear {
            navigateToYear(selectedYear + 1)
        }
    }
}

#Preview {
    ReleaseHistoryView()
        .modelContainer(for: Release.self, inMemory: true)
}

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

    private let currentYear: Int

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

    private var yearNavigationBar: some View {
        HStack(spacing: DandelionSpacing.lg) {
            Button {
                withAnimation(DandelionAnimation.gentle) {
                    selectedYear -= 1
                    loadData()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.dandelionPrimary)

            Text(verbatim: String(selectedYear))
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundColor(.dandelionPrimary)

            Button {
                withAnimation(DandelionAnimation.gentle) {
                    selectedYear += 1
                    loadData()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.dandelionPrimary)
            .disabled(selectedYear >= currentYear)
            .opacity(selectedYear >= currentYear ? 0.3 : 1)
        }
        .padding(.vertical, DandelionSpacing.sm)
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

        if translation.width > 0 {
            withAnimation(DandelionAnimation.gentle) {
                selectedYear -= 1
                loadData()
            }
        } else if selectedYear < currentYear {
            withAnimation(DandelionAnimation.gentle) {
                selectedYear += 1
                loadData()
            }
        }
    }
}

#Preview {
    ReleaseHistoryView()
        .modelContainer(for: Release.self, inMemory: true)
}

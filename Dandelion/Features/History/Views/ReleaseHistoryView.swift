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
        GeometryReader { proxy in
            let headerHeight: CGFloat = 32
            let spacing: CGFloat = DandelionSpacing.xs
            let bottomPadding: CGFloat = DandelionSpacing.xs
            let topInset = topSafeArea + DandelionSpacing.md
            let gridHeight = max(
                0,
                proxy.size.height - topInset - headerHeight - spacing - bottomPadding
            )

            ZStack(alignment: .top) {
                YearGridView(
                    year: selectedYear,
                    releaseDates: releaseDates
                )
                .frame(height: gridHeight)
                .padding(.top, topInset + headerHeight + spacing)
                .padding(.horizontal, DandelionSpacing.md)

                headerView
                    .frame(height: headerHeight)
                    .padding(.horizontal, DandelionSpacing.lg)
                    .padding(.top, topInset)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .padding(.bottom, bottomPadding)
            .background(Color.dandelionBackground.ignoresSafeArea())
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        handleYearSwipe(translation: value.translation)
                    }
            )
        }
        .onAppear {
            releaseHistoryService = ReleaseHistoryService(modelContext: modelContext)
            loadData()
        }
        .onChange(of: allReleases) { _, _ in
            loadData()
        }
    }

    private var headerView: some View {
        HStack {
            HStack(spacing: DandelionSpacing.md) {
                Button {
                    withAnimation(DandelionAnimation.gentle) {
                        selectedYear -= 1
                        loadData()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .foregroundColor(.dandelionPrimary)

                Text(verbatim: String(selectedYear))
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundColor(.dandelionPrimary)

                Button {
                    withAnimation(DandelionAnimation.gentle) {
                        selectedYear += 1
                        loadData()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(.dandelionPrimary)
                .disabled(selectedYear >= currentYear)
                .opacity(selectedYear >= currentYear ? 0.3 : 1)
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    onNavigateToWriting()
                }
            } label: {
                Image("Dandelion")
                    .renderingMode(Image.TemplateRenderingMode.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(Color.dandelionSecondary)
            }
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

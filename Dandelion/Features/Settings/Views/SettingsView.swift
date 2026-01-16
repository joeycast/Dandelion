//
//  SettingsView.swift
//  Dandelion
//
//  Settings sheet with access to release history
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ReleaseHistoryView()
                    } label: {
                        Label("Release History", systemImage: "calendar")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.dandelionBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.dandelionBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.dandelionPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    SettingsView()
}

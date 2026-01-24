//
//  PromptsSettingsView.swift
//  Dandelion
//
//  Manage custom and default prompts (Dandelion Bloom)
//

import SwiftUI
import SwiftData

struct PromptsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumManager.self) private var premium
    @Environment(AppearanceManager.self) private var appearance
    @Query(sort: \CustomPrompt.createdAt) private var customPrompts: [CustomPrompt]
    @Query private var defaultPromptSettings: [DefaultPromptSetting]

    @State private var showEditor: Bool = false
    @State private var showPaywall: Bool = false
    @State private var editorText: String = ""
    @State private var editingPrompt: CustomPrompt?

    var body: some View {
        let theme = appearance.theme

        List {
            if premium.isBloomUnlocked {
                // Custom prompts section
                Section {
                    ForEach(customPrompts) { prompt in
                        PromptRow(prompt: prompt)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    modelContext.delete(prompt)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    editingPrompt = prompt
                                    editorText = prompt.text
                                    showEditor = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(theme.accent)
                            }
                            .listRowBackground(theme.card)
                    }

                    if customPrompts.isEmpty {
                        Text("Tap + to add your own prompts")
                            .font(.dandelionCaption)
                            .foregroundColor(theme.secondary)
                            .listRowBackground(theme.card)
                    }
                } header: {
                    Text("Custom Prompts")
                        .foregroundColor(theme.secondary)
                }

                // Default prompts section with toggles
                Section {
                    ForEach(WritingPrompt.defaults) { prompt in
                        Button {
                            toggleDefaultPrompt(prompt)
                        } label: {
                            HStack {
                                Text(prompt.text)
                                    .font(.dandelionSecondary)
                                    .foregroundColor(isDefaultPromptEnabled(prompt) ? theme.text : theme.secondary)
                                    .lineLimit(2)
                                Spacer()
                                Image(systemName: isDefaultPromptEnabled(prompt) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isDefaultPromptEnabled(prompt) ? theme.accent : theme.subtle)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(theme.card)
                    }
                } header: {
                    HStack {
                        Text("Curated Prompts")
                            .foregroundColor(theme.secondary)
                        Spacer()
                        Button(allDefaultPromptsEnabled() ? "Deselect All" : "Select All") {
                            setAllDefaultPrompts(enabled: !allDefaultPromptsEnabled())
                        }
                        .font(.dandelionCaption)
                        .foregroundColor(theme.accent)
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Disable prompts you don't want to see")
                        .font(.dandelionCaption)
                        .foregroundColor(theme.secondary)
                }
            } else {
                // Locked state for non-Bloom users
                Section {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Text("Add your own prompts")
                                .font(.dandelionSecondary)
                                .foregroundColor(theme.secondary)
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(theme.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.card)
                } header: {
                    Text("Custom Prompts")
                        .foregroundColor(theme.secondary)
                } footer: {
                    (Text("Create your own prompts with ") +
                    Text("Dandelion Bloom")
                        .foregroundColor(theme.accent) +
                    Text("."))
                    .onTapGesture { showPaywall = true }
                }

                // Show curated prompts (read-only for non-Bloom)
                Section {
                    ForEach(WritingPrompt.defaults) { prompt in
                        Text(prompt.text)
                            .font(.dandelionSecondary)
                            .foregroundColor(theme.text)
                            .listRowBackground(theme.card)
                    }
                } header: {
                    Text("Curated Prompts")
                        .foregroundColor(theme.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .navigationTitle("Prompts")
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.primary)
        .toolbarBackground(theme.background, for: .navigationBar)
        .toolbarColorScheme(appearance.colorScheme, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if premium.isBloomUnlocked {
                        editorText = ""
                        editingPrompt = nil
                        showEditor = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            PromptEditorView(
                text: $editorText,
                onSave: savePrompt,
                onCancel: { showEditor = false }
            )
        }
        .sheet(isPresented: $showPaywall) {
            BloomPaywallView(onClose: { showPaywall = false })
        }
    }

    private func savePrompt() {
        let trimmed = editorText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showEditor = false
            return
        }

        if let editingPrompt {
            editingPrompt.text = trimmed
        } else {
            let newPrompt = CustomPrompt(text: trimmed)
            modelContext.insert(newPrompt)
        }
        showEditor = false
    }

    private func isDefaultPromptEnabled(_ prompt: WritingPrompt) -> Bool {
        // If no setting exists, prompt is enabled by default
        guard let setting = defaultPromptSettings.first(where: { $0.promptId == prompt.id }) else {
            return true
        }
        return setting.isEnabled
    }

    private func toggleDefaultPrompt(_ prompt: WritingPrompt) {
        if let setting = defaultPromptSettings.first(where: { $0.promptId == prompt.id }) {
            // Toggle existing setting
            setting.isEnabled.toggle()
        } else {
            // Create new setting (disabled, since it was enabled by default)
            let newSetting = DefaultPromptSetting(promptId: prompt.id, isEnabled: false)
            modelContext.insert(newSetting)
        }
    }

    private func allDefaultPromptsEnabled() -> Bool {
        WritingPrompt.defaults.allSatisfy { isDefaultPromptEnabled($0) }
    }

    private func setAllDefaultPrompts(enabled: Bool) {
        let settingsById = Dictionary(uniqueKeysWithValues: defaultPromptSettings.map { ($0.promptId, $0) })
        for prompt in WritingPrompt.defaults {
            if let setting = settingsById[prompt.id] {
                setting.isEnabled = enabled
            } else if !enabled {
                modelContext.insert(DefaultPromptSetting(promptId: prompt.id, isEnabled: false))
            }
        }
    }
}

private struct PromptRow: View {
    @Bindable var prompt: CustomPrompt
    @Environment(AppearanceManager.self) private var appearance

    var body: some View {
        let theme = appearance.theme

        Toggle(isOn: $prompt.isActive) {
            Text(prompt.text)
                .font(.dandelionSecondary)
                .foregroundColor(theme.text)
        }
        .toggleStyle(SwitchToggleStyle(tint: theme.accent))
    }
}

private struct PromptEditorView: View {
    @Binding var text: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(AppearanceManager.self) private var appearance
    @FocusState private var isFocused: Bool

    var body: some View {
        let theme = appearance.theme

        NavigationStack {
            VStack(spacing: DandelionSpacing.md) {
                TextField("Your prompt...", text: $text, axis: .vertical)
                    .font(.dandelionSecondary)
                    .foregroundColor(theme.text)
                    .focused($isFocused)
                    .padding(DandelionSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.subtle, lineWidth: 1)
                    )
                    .padding(.horizontal, DandelionSpacing.lg)

                Spacer()
            }
            .padding(.top, DandelionSpacing.lg)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.background, for: .navigationBar)
            .toolbarColorScheme(appearance.colorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(theme.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { onSave() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(theme.primary)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        PromptsSettingsView()
    }
    .environment(PremiumManager.shared)
    .environment(AppearanceManager())
    .modelContainer(for: [CustomPrompt.self, DefaultPromptSetting.self], inMemory: true)
}

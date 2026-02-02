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
#if os(macOS)
    @State private var isAddingPrompt: Bool = false
    @State private var newPromptText: String = ""
    @FocusState private var isNewPromptFocused: Bool
#endif

    var body: some View {
        let theme = appearance.theme

#if os(macOS)
        promptsForm
            .formStyle(.grouped)
#else
        promptsList
            .dandelionListStyle()
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle("Prompts")
            .dandelionNavigationBarStyle(background: theme.background, colorScheme: appearance.colorScheme)
#endif
    }

#if os(macOS)
    private var promptsForm: some View {
        Form {
            if premium.isBloomUnlocked {
                Section {
                    ForEach(customPrompts) { prompt in
                        MacPromptRow(
                            prompt: prompt,
                            onDelete: { modelContext.delete(prompt) }
                        )
                    }

                    if isAddingPrompt {
                        HStack {
                            TextField("Enter your prompt...", text: $newPromptText)
                                .textFieldStyle(.plain)
                                .focused($isNewPromptFocused)
                                .onSubmit {
                                    saveNewPrompt()
                                }
                                .onExitCommand {
                                    cancelNewPrompt()
                                }

                            Button("Add") {
                                saveNewPrompt()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("Cancel") {
                                cancelNewPrompt()
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Button {
                            isAddingPrompt = true
                            newPromptText = ""
                            isNewPromptFocused = true
                        } label: {
                            Label("Add Prompt", systemImage: "plus")
                        }
                    }
                } header: {
                    Text("Custom Prompts")
                }

                Section {
                    ForEach(WritingPrompt.defaults) { prompt in
                        Toggle(isOn: Binding(
                            get: { isDefaultPromptEnabled(prompt) },
                            set: { _ in toggleDefaultPrompt(prompt) }
                        )) {
                            Text(prompt.text)
                                .font(.dandelionSecondary)
                                .lineLimit(2)
                        }
                    }
                } header: {
                    HStack {
                        Text("Curated Prompts")
                        Spacer()
                        Button(allDefaultPromptsEnabled() ? "Deselect All" : "Select All") {
                            setAllDefaultPrompts(enabled: !allDefaultPromptsEnabled())
                        }
                        .font(.dandelionCaption)
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Section {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Label("Add Prompt", systemImage: "plus")
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Custom Prompts")
                } footer: {
                    Text("Create your own prompts with Dandelion Bloom.")
                }

                Section {
                    ForEach(WritingPrompt.defaults) { prompt in
                        Text(prompt.text)
                            .font(.dandelionSecondary)
                    }
                } header: {
                    Text("Curated Prompts")
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            BloomPaywallView(onClose: { showPaywall = false })
        }
    }

    private func saveNewPrompt() {
        let trimmed = newPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelNewPrompt()
            return
        }
        let newPrompt = CustomPrompt(text: trimmed)
        modelContext.insert(newPrompt)
        cancelNewPrompt()
    }

    private func cancelNewPrompt() {
        isAddingPrompt = false
        newPromptText = ""
        isNewPromptFocused = false
    }
#endif

    private var promptsList: some View {
        let theme = appearance.theme

        return List {
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
                        let isEnabled = isDefaultPromptEnabled(prompt)
                        Button {
                            toggleDefaultPrompt(prompt)
                        } label: {
                            HStack {
                                Text(prompt.text)
                                    .font(.dandelionSecondary)
                                    .foregroundColor(isEnabled ? theme.text : theme.secondary)
                                    .lineLimit(2)
                                Spacer()
                                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isEnabled ? theme.accent : theme.subtle)
                                    .accessibilityHidden(true)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(theme.card)
                        .accessibilityLabel(prompt.text)
                        .accessibilityValue(isEnabled ? "Enabled" : "Disabled")
                        .accessibilityHint("Tap to \(isEnabled ? "disable" : "enable") this prompt")
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
                        .accessibilityHint("Toggle all curated prompts at once")
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
#if os(iOS)
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
                .accessibilityLabel("Add custom prompt")
                .accessibilityHint(premium.isBloomUnlocked ? "Create a new custom prompt" : "Unlock with Dandelion Bloom")
            }
        }
        .sheet(isPresented: $showEditor) {
            PromptEditorView(
                text: $editorText,
                onSave: savePrompt,
                onCancel: { showEditor = false }
            )
            .preferredColorScheme(appearance.colorScheme)
        }
        .sheet(isPresented: $showPaywall) {
            BloomPaywallView(onClose: { showPaywall = false })
        }
#endif
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
        let setting = upsertDefaultPromptSetting(promptId: prompt.id, defaultIsEnabled: true)
        setting.isEnabled.toggle()
    }

    private func allDefaultPromptsEnabled() -> Bool {
        WritingPrompt.defaults.allSatisfy { isDefaultPromptEnabled($0) }
    }

    private func setAllDefaultPrompts(enabled: Bool) {
        for prompt in WritingPrompt.defaults {
            if let setting = defaultPromptSettings.first(where: { $0.promptId == prompt.id }) {
                setting.isEnabled = enabled
            } else if !enabled {
                let setting = upsertDefaultPromptSetting(promptId: prompt.id, defaultIsEnabled: false)
                setting.isEnabled = false
            }
        }
    }

    private func upsertDefaultPromptSetting(promptId: String, defaultIsEnabled: Bool) -> DefaultPromptSetting {
        if let existing = defaultPromptSettings.first(where: { $0.promptId == promptId }) {
            return existing
        }
        let setting = DefaultPromptSetting(promptId: promptId, isEnabled: defaultIsEnabled)
        modelContext.insert(setting)
        return setting
    }
}

#if os(macOS)
private struct MacPromptRow: View {
    @Bindable var prompt: CustomPrompt
    let onDelete: () -> Void
    @State private var isEditing: Bool = false
    @State private var editText: String = ""
    @FocusState private var isEditFocused: Bool

    var body: some View {
        HStack {
            if isEditing {
                TextField("Edit prompt...", text: $editText)
                    .textFieldStyle(.plain)
                    .focused($isEditFocused)
                    .onSubmit {
                        saveEdit()
                    }
                    .onExitCommand {
                        cancelEdit()
                    }

                Button("Save") {
                    saveEdit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Cancel") {
                    cancelEdit()
                }
                .buttonStyle(.bordered)
            } else {
                Toggle(isOn: $prompt.isActive) {
                    Text(prompt.text)
                }

                Button {
                    editText = prompt.text
                    isEditing = true
                    isEditFocused = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func saveEdit() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            prompt.text = trimmed
        }
        cancelEdit()
    }

    private func cancelEdit() {
        isEditing = false
        editText = ""
        isEditFocused = false
    }
}
#endif

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
            .dandelionNavigationBarStyle(background: theme.background, colorScheme: appearance.colorScheme)
            .toolbar {
#if os(iOS)
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
#else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(theme.secondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { onSave() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(theme.primary)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
#endif
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

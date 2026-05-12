import SwiftUI

struct CategoryDetailView: View {
    let categoryId: Int
    /// Called on dismissal; `didChange == true` means the parent list should
    /// refetch (rename, archive, delete, restore all flip this).
    let onClose: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading: Bool = true
    @State private var loadError: String?

    @State private var original: CategoryListItem?
    @State private var otherCategoryNames: [String] = []
    @State private var emoji: String = "📁"
    @State private var name: String = ""
    @State private var definition: String = ""
    @State private var keywordsText: String = ""

    @State private var isSaving: Bool = false
    @State private var saveError: String?
    @State private var didChange: Bool = false

    @State private var showAddSubCategory: Bool = false
    @State private var showDeleteFlow: Bool = false
    @State private var showArchiveConfirm: Bool = false
    @State private var isPerformingDangerAction: Bool = false
    @State private var dangerError: String?

    @State private var isRecategorizing: Bool = false
    @State private var recategorizeMessage: String?

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, definition, keywords
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.textPrimary))
            } else if let error = loadError {
                VStack(spacing: Theme.spacingMD) {
                    Text("Couldn't load this category")
                        .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(error)
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        Task { await load() }
                    }
                    .foregroundColor(Theme.accent)
                }
                .padding()
            } else {
                editor
            }
        }
        .navigationTitle(original?.archived == true ? "Archived" : "Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task { await save() }
                    }
                    .foregroundColor(canSave ? Theme.accent : Theme.textTertiary)
                    .disabled(!canSave)
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
                    .foregroundColor(Theme.accent)
            }
        }
        .onDisappear { onClose(didChange) }
        .task { await load() }
        .sheet(isPresented: $showAddSubCategory, onDismiss: {
            Task { await load() }
        }) {
            AddSubCategoryView(categoryName: name) { _ in
                didChange = true
            }
        }
        .sheet(isPresented: $showDeleteFlow) {
            DeleteCategoryFlowView(
                category: original ?? placeholderItem(),
                otherCategoryNames: otherCategoryNames,
                onComplete: { result in
                    showDeleteFlow = false
                    if result != nil {
                        didChange = true
                        dismiss()
                    }
                }
            )
        }
        .alert("Archive category?", isPresented: $showArchiveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Archive") {
                Task { await archive() }
            }
        } message: {
            Text("Archived categories stop receiving new notes. You can restore later from this screen.")
        }
        .alert("Action failed", isPresented: Binding(
            get: { dangerError != nil },
            set: { if !$0 { dangerError = nil } }
        )) {
            Button("OK", role: .cancel) { dangerError = nil }
        } message: {
            Text(dangerError ?? "")
        }
    }

    // MARK: - Editor

    @ViewBuilder
    private var editor: some View {
        let locked = original?.isLocked == true
        let archived = original?.archived == true
        let readonly = locked || archived

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingLG) {
                if locked {
                    LockNotice(count: original?.inProcessCount ?? 0)
                }

                if archived {
                    ArchivedNotice()
                }

                // Emoji + name
                HStack(alignment: .center, spacing: Theme.spacingMD) {
                    EmojiInputField(emoji: $emoji)
                        .disabled(readonly)

                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("Name")
                            .font(.system(size: Theme.fontSizeSM, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        TextField("Name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: Theme.fontSizeMD))
                            .foregroundColor(Theme.textPrimary)
                            .padding(Theme.spacingMD)
                            .background(Theme.surface)
                            .cornerRadius(Theme.cornerRadiusSM)
                            .focused($focusedField, equals: .name)
                            .disabled(readonly)
                    }
                }

                // Description
                VStack(alignment: .leading, spacing: Theme.spacingSM) {
                    Text("Description")
                        .font(.system(size: Theme.fontSizeSM, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    TextField("What kind of notes belong here?", text: $definition, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: Theme.fontSizeMD))
                        .foregroundColor(Theme.textPrimary)
                        .padding(Theme.spacingMD)
                        .background(Theme.surface)
                        .cornerRadius(Theme.cornerRadiusSM)
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .definition)
                        .disabled(readonly)
                }

                // Keywords
                VStack(alignment: .leading, spacing: Theme.spacingSM) {
                    Text("Keywords (comma-separated)")
                        .font(.system(size: Theme.fontSizeSM, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    TextField("e.g., launch, retro, planning", text: $keywordsText)
                        .textFieldStyle(.plain)
                        .font(.system(size: Theme.fontSizeMD))
                        .foregroundColor(Theme.textPrimary)
                        .padding(Theme.spacingMD)
                        .background(Theme.surface)
                        .cornerRadius(Theme.cornerRadiusSM)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .keywords)
                        .disabled(readonly)
                }

                if let error = saveError {
                    Text(error)
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(.red)
                }

                // Sub-categories
                VStack(alignment: .leading, spacing: Theme.spacingSM) {
                    HStack {
                        Text("Sub-categories")
                            .font(.system(size: Theme.fontSizeSM, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        if let subCount = original?.subCatCount, subCount > 0 {
                            Text("\(subCount)")
                                .font(.system(size: Theme.fontSizeXS))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }

                    Button {
                        showAddSubCategory = true
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add sub-category")
                            Spacer()
                        }
                        .font(.system(size: Theme.fontSizeMD))
                        .foregroundColor(readonly ? Theme.textTertiary : Theme.accent)
                        .padding(Theme.spacingMD)
                        .background(Theme.surface)
                        .cornerRadius(Theme.cornerRadiusSM)
                    }
                    .disabled(readonly)
                }

                // Re-categorize past notes (stubbed)
                VStack(alignment: .leading, spacing: Theme.spacingSM) {
                    Button {
                        Task { await recategorize() }
                    } label: {
                        HStack {
                            if isRecategorizing {
                                ProgressView().progressViewStyle(.circular)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text("Re-categorize past notes")
                            Spacer()
                        }
                        .padding(Theme.spacingMD)
                        .background(Theme.surface)
                        .cornerRadius(Theme.cornerRadiusSM)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(readonly ? Theme.textTertiary : Theme.textPrimary)
                    .disabled(readonly || isRecategorizing)

                    Text("Re-runs the AI against notes already in this category. Uses tokens. Runs in the background for up to 24 hours.")
                        .font(.system(size: Theme.fontSizeXS))
                        .foregroundColor(Theme.textTertiary)

                    if let message = recategorizeMessage {
                        Text(message)
                            .font(.system(size: Theme.fontSizeXS))
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                // Danger zone
                dangerZone(archived: archived, locked: locked)

                Spacer(minLength: Theme.spacingXL)
            }
            .padding(Theme.spacingLG)
        }
    }

    // MARK: - Danger zone

    @ViewBuilder
    private func dangerZone(archived: Bool, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text("Danger zone")
                .sectionLabel()
                .foregroundColor(Theme.textSecondary)
                .padding(.top, Theme.spacingMD)

            if archived {
                Button {
                    Task { await restore() }
                } label: {
                    dangerLabel(systemImage: "arrow.uturn.backward", title: "Restore category", tint: Theme.accent)
                }
                .disabled(isPerformingDangerAction)
            } else {
                Button {
                    showArchiveConfirm = true
                } label: {
                    dangerLabel(systemImage: "archivebox", title: "Archive category", tint: Theme.textPrimary)
                }
                .disabled(locked || isPerformingDangerAction)
            }

            if !archived {
                Button(role: .destructive) {
                    showDeleteFlow = true
                } label: {
                    dangerLabel(systemImage: "trash", title: "Delete category", tint: .red)
                }
                .disabled(locked || isPerformingDangerAction)
            }

            if locked {
                Text("Some notes are still being categorized. Try again once they're done.")
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    private func dangerLabel(systemImage: String, title: String, tint: Color) -> some View {
        HStack {
            Image(systemName: systemImage)
            Text(title)
            Spacer()
        }
        .font(.system(size: Theme.fontSizeMD))
        .foregroundColor(tint)
        .padding(Theme.spacingMD)
        .background(Theme.surface)
        .cornerRadius(Theme.cornerRadiusSM)
    }

    // MARK: - State

    private var canSave: Bool {
        guard let original else { return false }
        if isSaving { return false }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { return false }
        if original.isLocked || original.archived { return false }
        let keywords = parseKeywords(keywordsText)
        return trimmedName != original.name
            || definition != original.definition
            || keywords != original.keywords
            || CategoryEmojiStore.emoji(for: categoryId) != emoji
    }

    private func placeholderItem() -> CategoryListItem {
        CategoryListItem(
            id: categoryId, name: name, definition: definition,
            keywords: parseKeywords(keywordsText), source: "user",
            noteCount: original?.noteCount ?? 0,
            subCatCount: original?.subCatCount ?? 0,
            inProcessCount: 0, archived: false, archivedAt: nil
        )
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            async let categoriesResp = NotesService.shared.fetchCategories()
            async let countsResp = NotesService.shared.fetchCounts()
            let (categories, counts) = try await (categoriesResp, countsResp)

            guard let match = categories.categories.first(where: { $0.categoryId == categoryId }) else {
                loadError = "Category no longer exists."
                isLoading = false
                return
            }
            let item = CategoryListItem.make(
                from: match,
                noteCount: counts.categories[match.name] ?? 0
            )
            original = item
            otherCategoryNames = categories.categories
                .filter { $0.categoryId != categoryId && ($0.archived ?? false) == false }
                .map { $0.name }
                .sorted { $0.lowercased() < $1.lowercased() }
            emoji = match.emoji ?? CategoryEmojiStore.emoji(for: categoryId)
            name = item.name
            definition = item.definition
            keywordsText = item.keywords.joined(separator: ", ")
            isLoading = false
        } catch {
            loadError = error.localizedDescription
            isLoading = false
        }
    }

    private func save() async {
        guard let original else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDef = definition.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedKeywords = parseKeywords(keywordsText)

        let update = CategoryUpdateRequest(
            categoryName: trimmedName != original.name ? trimmedName : nil,
            categoryDescription: trimmedDef != original.definition ? trimmedDef : nil,
            keywords: parsedKeywords != original.keywords ? parsedKeywords : nil
        )

        // Local-only: persist emoji.
        CategoryEmojiStore.setEmoji(emoji, for: categoryId)

        // If only the emoji changed, skip the network round-trip.
        if update.categoryName == nil
            && update.categoryDescription == nil
            && update.keywords == nil {
            didChange = true
            await load()
            return
        }

        isSaving = true
        saveError = nil
        do {
            _ = try await NotesService.shared.updateCategory(id: categoryId, update: update)
            didChange = true
            await load()
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }

    private func recategorize() async {
        isRecategorizing = true
        recategorizeMessage = nil
        defer { isRecategorizing = false }
        do {
            let response = try await NotesService.shared.recategorizePastNotes(categoryId: categoryId)
            if let affected = response.affectedCount {
                recategorizeMessage = "Queued \(affected) note\(affected == 1 ? "" : "s"). This can take up to 24h."
            } else {
                recategorizeMessage = "Re-categorization queued. This can take up to 24h."
            }
        } catch {
            recategorizeMessage = error.localizedDescription
        }
    }

    private func archive() async {
        isPerformingDangerAction = true
        defer { isPerformingDangerAction = false }
        do {
            try await NotesService.shared.archiveCategory(categoryId: categoryId)
            didChange = true
            dismiss()
        } catch {
            dangerError = error.localizedDescription
        }
    }

    private func restore() async {
        isPerformingDangerAction = true
        defer { isPerformingDangerAction = false }
        do {
            try await NotesService.shared.restoreCategory(categoryId: categoryId)
            didChange = true
            dismiss()
        } catch {
            dangerError = error.localizedDescription
        }
    }

    // MARK: - Parsing

    private func parseKeywords(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Sub-components

struct EmojiInputField: View {
    @Binding var emoji: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingXS) {
            Text("Emoji")
                .font(.system(size: Theme.fontSizeSM, weight: .medium))
                .foregroundColor(Theme.textPrimary)
            TextField("📁", text: Binding(
                get: { emoji },
                set: { newValue in
                    // Keep at most one extended grapheme cluster (one emoji).
                    if let first = newValue.first {
                        emoji = String(first)
                    } else {
                        emoji = "📁"
                    }
                }
            ))
            .font(.system(size: 28))
            .multilineTextAlignment(.center)
            .frame(width: 60, height: 60)
            .background(Theme.surface)
            .cornerRadius(Theme.cornerRadiusCatIcon)
        }
    }
}

private struct LockNotice: View {
    let count: Int

    var body: some View {
        HStack(spacing: Theme.spacingSM) {
            Image(systemName: "lock.fill")
                .foregroundColor(Theme.warning)
            Text("\(count) note\(count == 1 ? "" : "s") still processing — editing and deletion are paused.")
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(Theme.spacingMD)
        .background(Theme.warning.opacity(0.12))
        .cornerRadius(Theme.cornerRadiusSM)
    }
}

private struct ArchivedNotice: View {
    var body: some View {
        HStack(spacing: Theme.spacingSM) {
            Image(systemName: "archivebox.fill")
                .foregroundColor(Theme.textSecondary)
            Text("This category is archived. New notes won't be sorted into it. Restore to resume.")
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(Theme.spacingMD)
        .background(Theme.surface2)
        .cornerRadius(Theme.cornerRadiusSM)
    }
}

import SwiftUI

struct CategoryDetailView: View {
    let categoryId: Int
    /// Called on dismissal; `didChange == true` means the parent list should
    /// refetch (edit-save, archive, restore, recategorize all flip this).
    let onClose: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var recategorizationTracker: CategoryRecategorizationTracker

    @State private var isLoading: Bool = true
    @State private var loadError: String?

    @State private var original: CategoryListItem?
    /// Every other category name (active + archived). Archived names are still
    /// owned by the server, so renaming onto one collides.
    @State private var reservedNames: [String] = []
    @State private var emoji: String = "📁"
    @State private var loadedEmoji: String = "📁"
    @State private var name: String = ""
    @State private var definition: String = ""
    @State private var keywordsText: String = ""

    @State private var isSaving: Bool = false
    @State private var saveError: String?
    @State private var didChange: Bool = false

    @State private var showAddSubCategory: Bool = false
    @State private var isPerformingDangerAction: Bool = false
    @State private var dangerError: String?

    @State private var choiceTrigger: RecategorizeChoiceView.Trigger?

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, definition, keywords
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if isLoading && original == nil {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.textPrimary))
            } else if let error = loadError, original == nil {
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
        .onReceive(NotificationCenter.default.publisher(for: .categoryRecategorizationDidFinish)) { notification in
            guard let updatedCategoryId = notification.userInfo?["categoryId"] as? Int,
                  updatedCategoryId == categoryId else { return }
            Task { await load() }
        }
        .sheet(isPresented: $showAddSubCategory, onDismiss: {
            Task { await load() }
        }) {
            AddSubCategoryView(categoryName: original?.name ?? name) { _ in
                didChange = true
            }
        }
        .sheet(item: $choiceTrigger) { trigger in
            RecategorizeChoiceView(
                categoryId: categoryId,
                categoryName: original?.name ?? name,
                categoryEmoji: loadedEmoji,
                noteCount: original?.noteCount ?? 0,
                trigger: trigger,
                onComplete: { outcome in
                    choiceTrigger = nil
                    if outcome != nil {
                        didChange = true
                        dismiss()
                    }
                }
            )
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
        let recategorizationJob = recategorizationTracker.job(for: categoryId)

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingLG) {
                if locked {
                    LockNotice(count: original?.inProcessCount ?? 0)
                }

                if let recategorizationJob {
                    CategoryRecategorizationNotice(job: recategorizationJob, isArchived: archived)
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

                        if nameCollides {
                            Text("A category named \"\(name.trimmingCharacters(in: .whitespacesAndNewlines))\" already exists.")
                                .font(.system(size: Theme.fontSizeXS))
                                .foregroundColor(.red)
                        }
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
                    choiceTrigger = .archiveTapped
                } label: {
                    dangerLabel(systemImage: "archivebox", title: "Archive category", tint: Theme.textPrimary)
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
        if nameCollides { return false }
        if original.isLocked || original.archived { return false }
        let trimmedDefinition = definition.trimmingCharacters(in: .whitespacesAndNewlines)
        let keywords = parseKeywords(keywordsText)
        return trimmedName != original.name
            || trimmedDefinition != original.definition
            || keywords != original.keywords
            || emoji != loadedEmoji
    }

    private var nameCollides: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return reservedNames.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            async let categoriesResp = NotesService.shared.fetchCategories()
            async let countsResp = NotesService.shared.fetchCounts()
            let (categories, counts) = try await (categoriesResp, countsResp)
            let countsByCategoryID = CategoryCountStore.countsByCategoryID(from: counts)

            guard let match = categories.categories.first(where: { $0.categoryId == categoryId }) else {
                loadError = "Category no longer exists."
                isLoading = false
                return
            }
            let item = CategoryListItem.make(
                from: match,
                noteCount: CategoryCountStore.noteCount(
                    for: match.categoryId,
                    countsByCategoryID: countsByCategoryID
                )
            )
            original = item
            reservedNames = categories.categories
                .filter { $0.categoryId != categoryId }
                .map { $0.name }
            let resolvedEmoji = match.emoji ?? CategoryEmojiStore.emoji(for: categoryId)
            loadedEmoji = resolvedEmoji
            emoji = resolvedEmoji
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

        // If only the emoji changed, skip the network round-trip and the
        // recategorize/archive prompt — the meaning of the category is unchanged.
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
            isSaving = false
            // Definition changed — force the user to choose between
            // re-running AI on past notes or archiving the category.
            choiceTrigger = .edited
            return
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
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
                    // Keep at most one extended grapheme cluster. Take the
                    // *last* character so appending a new emoji replaces the
                    // old one rather than being silently dropped. Allow empty
                    // so the field can be cleared; read sites fall back to 📁.
                    emoji = newValue.isEmpty ? "" : String(newValue.suffix(1))
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

private struct CategoryRecategorizationNotice: View {
    let job: CategoryRecategorizationTracker.Job
    let isArchived: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Theme.spacingSM) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                Text(title)
                    .font(.system(size: Theme.fontSizeSM, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Text(message)
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(Theme.spacingMD)
        .background(backgroundColor)
        .cornerRadius(Theme.cornerRadiusSM)
    }

    private var title: String {
        switch job.status {
        case .pending:
            return "Re-categorization queued"
        case .running:
            return "Re-categorizing past notes"
        case .failed:
            return "Re-categorization failed"
        case .done:
            return "Re-categorization complete"
        }
    }

    private var message: String {
        switch job.status {
        case .pending:
            if isArchived {
                return "This category is archived, and its past notes are queued to be re-sorted. They may still appear here until the job starts."
            }
            return "Past notes in this category are queued to be re-sorted against the updated definition. They may still appear here until the job starts."
        case .running:
            if job.total > 0 {
                if isArchived {
                    return "\(job.processed) of \(job.total) notes checked so far, with \(job.moved) moved. Notes may remain here until this finishes."
                }
                return "\(job.processed) of \(job.total) notes checked so far, with \(job.moved) moved. Notes may stay here or move elsewhere until this finishes."
            }
            return isArchived
                ? "Past notes are being re-sorted now. Notes may remain here until this finishes."
                : "Past notes are being re-sorted now. Notes may stay here or move elsewhere until this finishes."
        case .failed:
            if let errorMessage = job.errorMessage, !errorMessage.isEmpty {
                return "The re-categorization job failed: \(errorMessage)"
            }
            return "The re-categorization job failed before the notes finished moving."
        case .done:
            return "Past notes have finished re-categorizing."
        }
    }

    private var iconName: String {
        switch job.status {
        case .failed:
            return "exclamationmark.triangle.fill"
        case .pending, .running, .done:
            return "arrow.triangle.2.circlepath"
        }
    }

    private var iconColor: Color {
        switch job.status {
        case .failed:
            return .red
        case .pending, .running:
            return Theme.warning
        case .done:
            return Theme.success
        }
    }

    private var backgroundColor: Color {
        switch job.status {
        case .failed:
            return Color.red.opacity(0.08)
        case .pending, .running:
            return Theme.warning.opacity(0.12)
        case .done:
            return Theme.success.opacity(0.12)
        }
    }
}

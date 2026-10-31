import SwiftUI

// The two ways to move a note (Paper, 04 Note): the Category sheet from the
// category chip, where picking a category saves it and closes the sheet, and
// the Move panel for the category, sub-categories and type together.

/// Cancel / title / optional trailing action, as on Paper's sheets.
private struct SheetHeader<Trailing: View>: View {
    let title: String
    let onCancel: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .buttonStyle(TDTextLinkStyle(size: 16))
                .frame(width: 72, alignment: .leading)
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            trailing()
                .frame(width: 72, alignment: .trailing)
        }
        .frame(height: 52)
        .padding(.horizontal, Theme.spacingSMPlus)
    }
}

/// "a and b", "a, b and c".
private func spokenList(_ names: [String]) -> String {
    guard names.count > 1, let last = names.last else { return names.first ?? "" }
    return names.dropLast().joined(separator: ", ") + " and " + last
}

/// Tap the category chip: the categories, the current one ticked. Picking
/// another saves the move and closes the sheet.
struct NoteCategorySheet: View {
    @ObservedObject var viewModel: NoteDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var savingCategoryKey: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Category", onCancel: { dismiss() }) { EmptyView() }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let current = viewModel.note?.sub_cat_names?.filter { !$0.isEmpty } ?? []
                    if !current.isEmpty {
                        Text("Moving removes the sub-categories \(spokenList(current)).")
                            .tdCaption()
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.bottom, Theme.spacingXS)
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.vertical, Theme.spacingSM)
                    }
                    if !viewModel.editOptions.isLoaded {
                        Text(viewModel.editOptionsError ?? "Loading…")
                            .tdCaption()
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.vertical, Theme.spacingSMPlus)
                    }
                    let choices = viewModel.moveCategoryChoices
                    ForEach(Array(choices.enumerated()), id: \.element.key) { index, choice in
                        if index > 0 {
                            TDHairline()
                        }
                        categoryRow(choice)
                    }
                }
                .padding(.horizontal, Theme.screenH)
                .padding(.bottom, Theme.spacingLG)
            }
        }
        .background(Theme.surface.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.surface)
        .task {
            if !viewModel.editOptions.isLoaded {
                await viewModel.loadEditOptions()
            }
        }
    }

    private func categoryRow(_ choice: NoteCategoryChoice) -> some View {
        let isCurrent = choice.id == viewModel.note?.category_id
        return Button {
            Task { await pick(choice, isCurrent: isCurrent) }
        } label: {
            HStack(spacing: Theme.spacingSMPlus) {
                HStack(spacing: 6) {
                    CategoryGlyph(emoji: choice.id.flatMap { viewModel.categoryEmojis[$0] }, size: 16)
                        .frame(width: 20)
                    Text(choice.label)
                        .tdBody()
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if savingCategoryKey == choice.key {
                    Text("Saving…")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                } else if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(TDPressStyle())
        .disabled(savingCategoryKey != nil)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func pick(_ choice: NoteCategoryChoice, isCurrent: Bool) async {
        guard !isCurrent else {
            dismiss()
            return
        }
        errorMessage = nil
        savingCategoryKey = choice.key
        let saved = await viewModel.applyMove(category: choice, subCategories: nil, type: nil)
        savingCategoryKey = nil
        if saved {
            dismiss()
        } else {
            errorMessage = viewModel.errorMessage ?? "Couldn't move the note."
        }
    }
}

/// Move (or "•••" → Move): category, sub-categories (up to 3) and type,
/// saved together with Done.
struct NoteMoveSheet: View {
    @ObservedObject var viewModel: NoteDetailViewModel
    @ObservedObject private var noteTypes = NoteTypeCatalog.shared
    @Environment(\.dismiss) private var dismiss
    @State private var category: NoteCategoryChoice?
    @State private var subCategories: [String] = []
    @State private var noteType: String = ""
    @State private var didLoad = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Move note", onCancel: { dismiss() }) {
                Button("Done") {
                    Task { await save() }
                }
                .buttonStyle(TDTextLinkStyle(color: Theme.textPrimary, size: 16))
                .fontWeight(.medium)
                .disabled(isSaving || category == nil)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.bottom, Theme.spacingSM)
                    }

                    TDSectionLabel(title: "Category")
                        .padding(.bottom, Theme.spacingSM)
                    categoryPicker

                    TDSectionLabel(title: "Sub-categories")
                        .padding(.top, Theme.spacingLG)
                        .padding(.bottom, Theme.spacingSM)
                    subCategoryPicker

                    TDSectionLabel(title: "Type")
                        .padding(.top, Theme.spacingLG)
                        .padding(.bottom, Theme.spacingSM)
                    typePicker
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.screenH)
                .padding(.top, Theme.spacingSM)
                .padding(.bottom, Theme.spacingLG)
            }
        }
        .background(Theme.surface.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.surface)
        .task {
            if !viewModel.editOptions.isLoaded {
                await viewModel.loadEditOptions()
            }
            loadCurrent()
        }
        .onChange(of: viewModel.editOptions) { _, _ in
            loadCurrent()
        }
    }

    // MARK: Pickers

    private var categoryPicker: some View {
        Menu {
            ForEach(viewModel.moveCategoryChoices, id: \.key) { choice in
                Button {
                    select(choice)
                } label: {
                    if choice.key == category?.key {
                        Label(choice.label, systemImage: "checkmark")
                    } else {
                        Text(choice.label)
                    }
                }
            }
        } label: {
            NoteCategoryChipLabel(
                emoji: category?.id.flatMap { viewModel.categoryEmojis[$0] },
                name: category?.name ?? (viewModel.editOptions.isLoaded ? "Choose" : "Loading…")
            )
        }
        .accessibilityLabel("Category: \(category?.name ?? "none")")
    }

    @ViewBuilder
    private var subCategoryPicker: some View {
        let choices = availableSubCategories
        if choices.isEmpty {
            Text("\(category?.name ?? "This category") has no sub-categories.")
                .tdCaption()
                .foregroundStyle(Theme.textSecondary)
        } else {
            FlowLayout(spacing: Theme.spacingSM) {
                ForEach(choices, id: \.self) { name in
                    let isSelected = isSelected(name)
                    Button {
                        toggle(name)
                    } label: {
                        TDChip(title: name, isSelected: isSelected)
                    }
                    .buttonStyle(TDPressStyle())
                    .disabled(!isSelected && subCategories.count >= NoteEditDraft.maxSubCategories)
                }
            }
            Text("Up to 3.")
                .tdCaption()
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, Theme.spacingXS)
        }
        let dropped = droppedSubCategories
        if !dropped.isEmpty, let name = category?.name {
            Text("Moving to \(name) removes \(spokenList(dropped)).")
                .tdCaption()
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, Theme.spacingSM)
        }
    }

    private var typePicker: some View {
        Menu {
            ForEach(typeChoices, id: \.value) { choice in
                Button {
                    noteType = choice.value
                } label: {
                    if NoteEditDraft.normalized(choice.value) == NoteEditDraft.normalized(noteType) {
                        Label(choice.label, systemImage: "checkmark")
                    } else {
                        Text(choice.label)
                    }
                }
            }
        } label: {
            HStack(spacing: Theme.spacingXS) {
                Text(noteType.isEmpty ? "No type" : noteType)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, Theme.spacingSM)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: Theme.radiusTag).fill(Theme.raised))
        }
        .accessibilityLabel("Type: \(noteType.isEmpty ? "none" : noteType)")
    }

    // MARK: State

    private var baseDraft: NoteEditDraft? {
        viewModel.note.map { NoteEditDraft(note: $0, noteTypes: noteTypes.types) }
    }

    private var typeChoices: [NoteTypeChoice] {
        baseDraft?.typeChoices(from: noteTypes.types) ?? []
    }

    /// The chosen category's sub-categories, plus the note's own when it
    /// stays in its category.
    private var availableSubCategories: [String] {
        guard let category else { return [] }
        var names = viewModel.editOptions.subCategories(forCategoryNamed: category.name)
        if category.id == viewModel.note?.category_id {
            for name in viewModel.note?.sub_cat_names ?? [] where !names.contains(where: {
                NoteEditDraft.normalized($0) == NoteEditDraft.normalized(name)
            }) {
                names.append(name)
            }
        }
        return names
    }

    private var droppedSubCategories: [String] {
        guard let category else { return [] }
        return viewModel.subCategoriesDropped(movingTo: category)
    }

    private func isSelected(_ name: String) -> Bool {
        subCategories.contains { NoteEditDraft.normalized($0) == NoteEditDraft.normalized(name) }
    }

    private func toggle(_ name: String) {
        if isSelected(name) {
            subCategories.removeAll { NoteEditDraft.normalized($0) == NoteEditDraft.normalized(name) }
        } else if subCategories.count < NoteEditDraft.maxSubCategories {
            subCategories.append(name)
        }
    }

    private func select(_ choice: NoteCategoryChoice) {
        guard choice.key != category?.key else { return }
        category = choice
        // Keep the sub-categories the new category also has; going back to
        // the note's own category puts its sub-categories back.
        if choice.id == viewModel.note?.category_id {
            subCategories = viewModel.note?.sub_cat_names?.filter { !$0.isEmpty } ?? []
        } else {
            let kept = Set(viewModel.editOptions.subCategories(forCategoryNamed: choice.name).map(NoteEditDraft.normalized))
            subCategories = subCategories.filter { kept.contains(NoteEditDraft.normalized($0)) }
        }
    }

    private func loadCurrent() {
        guard !didLoad, let note = viewModel.note else { return }
        let choices = viewModel.moveCategoryChoices
        category = choices.first { $0.id != nil && $0.id == note.category_id } ?? choices.first { $0.id == nil }
        subCategories = note.sub_cat_names?.filter { !$0.isEmpty } ?? []
        noteType = baseDraft?.noteType ?? (note.note_type ?? "")
        didLoad = viewModel.editOptions.isLoaded
    }

    private func save() async {
        guard let note = viewModel.note, let category else { return }
        errorMessage = nil
        isSaving = true
        let categoryChanged = category.id != nil && category.id != note.category_id
        let saved = await viewModel.applyMove(
            category: categoryChanged ? category : nil,
            subCategories: subCategories,
            type: noteType.isEmpty ? nil : noteType
        )
        isSaving = false
        if saved {
            dismiss()
        } else {
            errorMessage = viewModel.errorMessage ?? "Couldn't move the note."
        }
    }
}

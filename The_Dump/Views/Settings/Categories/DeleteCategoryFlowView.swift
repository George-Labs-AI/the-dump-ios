import SwiftUI

struct DeleteCategoryFlowView: View {
    let category: CategoryListItem
    let otherCategoryNames: [String]
    /// `nil` = cancelled, non-nil = the disposition the user confirmed.
    let onComplete: (DeleteCategoryDisposition?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selected: Option = .recategorize
    @State private var moveTarget: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    private enum Option: String, CaseIterable, Identifiable {
        case recategorize, moveAll, archive
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacingLG) {
                        header

                        VStack(spacing: Theme.spacingSM) {
                            OptionCard(
                                selected: selected == .recategorize,
                                title: "Re-categorize notes",
                                subtitle: "Let the AI re-sort \(category.noteCount) note\(category.noteCount == 1 ? "" : "s") into your remaining categories."
                            ) { selected = .recategorize }

                            OptionCard(
                                selected: selected == .moveAll,
                                title: "Move all to another category",
                                subtitle: "Bulk-assign every note here to a single category you pick."
                            ) { selected = .moveAll }

                            if selected == .moveAll {
                                MoveAllPicker(
                                    options: otherCategoryNames,
                                    selection: $moveTarget
                                )
                            }

                            OptionCard(
                                selected: selected == .archive,
                                title: "Archive instead",
                                subtitle: "Keep the category and its notes, but stop sorting new notes here."
                            ) { selected = .archive }
                        }

                        consequencesBox

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: Theme.fontSizeSM))
                                .foregroundColor(.red)
                        }

                        Button(action: confirm) {
                            if isSubmitting {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Theme.background))
                            } else {
                                Text(confirmTitle)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(PrimaryButtonStyle(isEnabled: canConfirm))
                        .disabled(!canConfirm)

                        Spacer(minLength: Theme.spacingMD)
                    }
                    .padding(Theme.spacingLG)
                }
            }
            .navigationTitle("Delete \(category.name)?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .interactiveDismissDisabled(isSubmitting)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onComplete(nil)
                        dismiss()
                    }
                    .foregroundColor(Theme.textSecondary)
                    .disabled(isSubmitting)
                }
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: Theme.spacingMD) {
            Text(CategoryEmojiStore.emoji(for: category.id))
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(Theme.surface2)
                .cornerRadius(Theme.cornerRadiusCatIcon)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.system(size: Theme.fontSizeLG, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("\(category.noteCount) \(category.noteCount == 1 ? "note" : "notes") · \(category.subCatCount) sub-cat\(category.subCatCount == 1 ? "" : "s")")
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
    }

    private var consequencesBox: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text("What happens")
                .sectionLabel()
                .foregroundColor(Theme.textSecondary)

            ForEach(consequences, id: \.self) { line in
                HStack(alignment: .top, spacing: Theme.spacingSM) {
                    Text("•")
                        .foregroundColor(Theme.textSecondary)
                    Text(line)
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(Theme.spacingMD)
        .background(Theme.surface)
        .cornerRadius(Theme.cornerRadiusSM)
    }

    private var consequences: [String] {
        switch selected {
        case .recategorize:
            return [
                "The AI re-sorts these notes into your remaining categories.",
                "Uses tokens. Runs in the background for up to 24h.",
                "The category itself is removed when sorting completes."
            ]
        case .moveAll:
            return [
                moveTarget.isEmpty
                    ? "Every note in this category will move to the category you pick."
                    : "Every note moves to \"\(moveTarget)\".",
                "Sub-categories on these notes are kept where possible.",
                "The category itself is removed immediately."
            ]
        case .archive:
            return [
                "Notes stay where they are.",
                "The category stops receiving new notes.",
                "You can restore it later from the Archived section."
            ]
        }
    }

    private var confirmTitle: String {
        switch selected {
        case .recategorize: return "Delete and re-categorize"
        case .moveAll: return moveTarget.isEmpty ? "Pick a target first" : "Delete and move to \(moveTarget)"
        case .archive: return "Archive instead"
        }
    }

    private var canConfirm: Bool {
        if isSubmitting { return false }
        switch selected {
        case .moveAll: return !moveTarget.isEmpty
        default: return true
        }
    }

    private func confirm() {
        guard canConfirm else { return }
        let disposition: DeleteCategoryDisposition = {
            switch selected {
            case .recategorize: return .recategorize
            case .moveAll: return .moveAll(targetName: moveTarget)
            case .archive: return .archiveInstead
            }
        }()

        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                try await NotesService.shared.deleteCategory(
                    categoryId: category.id,
                    disposition: disposition
                )
                await MainActor.run {
                    isSubmitting = false
                    onComplete(disposition)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct OptionCard: View {
    let selected: Bool
    let title: String
    let subtitle: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Theme.spacingMD) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(selected ? Theme.accent : Theme.textTertiary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    Text(title)
                        .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(Theme.spacingMD)
            .background(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSM)
                    .stroke(selected ? Theme.accent : Color.clear, lineWidth: 1.5)
            )
            .cornerRadius(Theme.cornerRadiusSM)
        }
        .buttonStyle(.plain)
    }
}

private struct MoveAllPicker: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingXS) {
            Text("Move to")
                .font(.system(size: Theme.fontSizeXS, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            if options.isEmpty {
                Text("No other categories to move to.")
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textTertiary)
                    .padding(Theme.spacingMD)
                    .background(Theme.surface2)
                    .cornerRadius(Theme.cornerRadiusSM)
            } else {
                Menu {
                    ForEach(options, id: \.self) { name in
                        Button(name) { selection = name }
                    }
                } label: {
                    HStack {
                        Text(selection.isEmpty ? "Pick a category…" : selection)
                            .foregroundColor(selection.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(Theme.textTertiary)
                    }
                    .padding(Theme.spacingMD)
                    .background(Theme.surface2)
                    .cornerRadius(Theme.cornerRadiusSM)
                }
            }
        }
        .padding(.leading, Theme.spacingXL)
    }
}

import SwiftUI

/// Presented after the user changes a category's name/description/keywords
/// or taps "Archive category" on `CategoryDetailView`.
///
/// - `.edited`: choose between re-running AI on past notes against the new
///   definition, or leaving past notes alone. The category stays active either
///   way — new notes can still be sorted into it.
/// - `.archiveTapped`: choose between redistributing past notes with AI or
///   keeping them here and archiving the category so no new notes land in it.
struct RecategorizeChoiceView: View {
    enum Outcome {
        case recategorized
        case archived
        /// `.edited` trigger only: user accepted the edits but opted not to
        /// re-run AI on past notes. No backend action is taken here — the
        /// edit itself was already saved before this sheet appeared.
        case keptAsIs
    }

    enum Trigger: String, Identifiable {
        case edited
        case archiveTapped

        var id: String { rawValue }
    }

    let categoryId: Int
    let categoryName: String
    let categoryEmoji: String
    let noteCount: Int
    let trigger: Trigger
    /// `nil` = cancelled. Non-nil = the action ran successfully.
    let onComplete: (Outcome?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selected: Choice
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    init(
        categoryId: Int,
        categoryName: String,
        categoryEmoji: String,
        noteCount: Int,
        trigger: Trigger,
        onComplete: @escaping (Outcome?) -> Void
    ) {
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.categoryEmoji = categoryEmoji
        self.noteCount = noteCount
        self.trigger = trigger
        self.onComplete = onComplete
        // Default to the no-cost option for edits (keep past notes alone) so
        // the user has to opt in to spending tokens. Archive flow keeps the
        // existing default of re-categorize. Done in init rather than
        // `.onAppear` so the first body evaluation already shows the right
        // selection — otherwise the wrong card flashes during the sheet
        // presentation animation.
        _selected = State(initialValue: trigger == .edited ? .keep : .recategorize)
    }

    private enum Choice: Hashable {
        /// Re-run AI on past notes. Valid for both triggers.
        case recategorize
        /// Archive the category. Valid only for `.archiveTapped`.
        case archive
        /// Leave past notes where they are. Valid only for `.edited`.
        case keep
    }

    /// The non-recategorize option, which differs by trigger.
    private var secondaryChoice: Choice {
        switch trigger {
        case .edited: return .keep
        case .archiveTapped: return .archive
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacingLG) {
                        header

                        Text(introCopy)
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: Theme.spacingSM) {
                            OptionCard(
                                selected: selected == .recategorize,
                                title: "Re-categorize past notes with AI",
                                subtitle: recategorizeSubtitle
                            ) { selected = .recategorize }

                            OptionCard(
                                selected: selected == secondaryChoice,
                                title: secondaryTitle,
                                subtitle: secondarySubtitle
                            ) { selected = secondaryChoice }
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: Theme.fontSizeSM))
                                .foregroundColor(.red)
                        }

                        Button(action: confirm) {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.background))
                            } else {
                                Text(confirmTitle)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(PrimaryButtonStyle(isEnabled: !isSubmitting))
                        .disabled(isSubmitting)

                        Spacer(minLength: Theme.spacingMD)
                    }
                    .padding(Theme.spacingLG)
                }
            }
            .navigationTitle(navTitle)
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
            Text(categoryEmoji)
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(Theme.surface2)
                .cornerRadius(Theme.cornerRadiusCatIcon)

            VStack(alignment: .leading, spacing: 2) {
                Text(categoryName)
                    .font(.system(size: Theme.fontSizeLG, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("\(noteCount) \(noteCount == 1 ? "note" : "notes")")
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
    }

    private var navTitle: String {
        switch trigger {
        case .edited: return "Category updated"
        case .archiveTapped: return "Archive \(categoryName)?"
        }
    }

    private var introCopy: String {
        switch trigger {
        case .edited:
            return "You changed this category. Want AI to re-sort the notes that were already in it so they reflect the new definition, or leave them where they are? This category stays active either way."
        case .archiveTapped:
            return "Do you want to re-categorize all notes that were previously in this category using AI, or keep them in this category and archive it so no new notes can be added?"
        }
    }

    private var recategorizeSubtitle: String {
        let noteWord = noteCount == 1 ? "note" : "notes"
        switch trigger {
        case .edited:
            return "AI will re-sort the \(noteCount) \(noteWord) that were in this category against the new definition. Some may move to other categories. Runs in the background for up to 24 hours and uses tokens. New notes can still be sorted into this category."
        case .archiveTapped:
            return "Let the AI re-sort the \(noteCount) \(noteWord) that were in this category. Past notes may move to other categories. Runs in the background for up to 24 hours and uses tokens."
        }
    }

    private var secondaryTitle: String {
        switch trigger {
        case .edited: return "Keep past notes where they are"
        case .archiveTapped: return "Keep past notes, archive category"
        }
    }

    private var secondarySubtitle: String {
        switch trigger {
        case .edited:
            return "Past notes stay in this category as-is. New notes can still be sorted into it — only future categorization uses the updated definition."
        case .archiveTapped:
            return "Past notes stay in this category. The category is archived — no new notes will be sorted here. You can restore it later."
        }
    }

    private var confirmTitle: String {
        switch selected {
        case .recategorize: return "Re-categorize past notes"
        case .archive: return "Archive category"
        case .keep: return "Keep past notes"
        }
    }

    private func confirm() {
        guard !isSubmitting else { return }
        errorMessage = nil

        // `.keep` is a pure dismissal — the edit was already saved before this
        // sheet appeared, so there's no network call to make or spinner to show.
        if selected == .keep {
            onComplete(.keptAsIs)
            dismiss()
            return
        }

        isSubmitting = true
        Task {
            do {
                switch selected {
                case .recategorize:
                    _ = try await NotesService.shared.startRecategorize(
                        scope: .category,
                        categoryId: categoryId
                    )
                    await MainActor.run {
                        isSubmitting = false
                        onComplete(.recategorized)
                        dismiss()
                    }
                case .archive:
                    try await NotesService.shared.archiveCategory(categoryId: categoryId)
                    await MainActor.run {
                        isSubmitting = false
                        onComplete(.archived)
                        dismiss()
                    }
                case .keep:
                    break // handled above
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
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSM)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSM)
                    .stroke(selected ? Theme.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

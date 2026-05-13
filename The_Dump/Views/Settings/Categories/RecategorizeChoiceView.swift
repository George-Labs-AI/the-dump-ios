import SwiftUI

/// Presented after the user changes a category's name/description/keywords
/// or taps "Archive category" on `CategoryDetailView`. Forces a choice
/// between recategorizing past notes against the (possibly updated)
/// definition and archiving the category so no new notes are sorted into it.
struct RecategorizeChoiceView: View {
    enum Outcome {
        case recategorized
        case archived
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

    @State private var selected: Choice = .recategorize
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    private enum Choice: Hashable {
        case recategorize, archive
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
                                subtitle: "Let the AI re-sort the \(noteCount) note\(noteCount == 1 ? "" : "s") that were in this category. Past notes may move to other categories. Runs in the background for up to 24 hours and uses tokens."
                            ) { selected = .recategorize }

                            OptionCard(
                                selected: selected == .archive,
                                title: "Keep past notes, archive category",
                                subtitle: "Past notes stay in this category. The category is archived — no new notes will be sorted here. You can restore it later."
                            ) { selected = .archive }
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
            return "You changed this category. Do you want to re-categorize all notes that were previously in this category using AI, or keep them in this category and archive it so no new notes can be added?"
        case .archiveTapped:
            return "Do you want to re-categorize all notes that were previously in this category using AI, or keep them in this category and archive it so no new notes can be added?"
        }
    }

    private var confirmTitle: String {
        switch selected {
        case .recategorize: return "Re-categorize past notes"
        case .archive: return "Archive category"
        }
    }

    private func confirm() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
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

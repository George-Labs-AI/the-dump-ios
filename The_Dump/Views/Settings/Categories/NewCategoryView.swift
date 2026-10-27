import SwiftUI

struct NewCategoryView: View {
    let existingNames: [String]

    @Environment(\.dismiss) private var dismiss

    @State private var emoji: String = "📁"
    @State private var name: String = ""
    @State private var definition: String = ""
    @State private var keywordsText: String = ""

    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, definition, keywords
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacingLG) {
                        HStack(alignment: .top, spacing: Theme.spacingMD) {
                            EmojiInputField(emoji: $emoji)

                            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                                Text("Name")
                                    .font(.system(size: Theme.fontSizeSM, weight: .medium))
                                    .foregroundColor(Theme.textPrimary)
                                TextField("e.g., Work", text: $name)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: Theme.fontSizeMD))
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(Theme.spacingMD)
                                    .background(Theme.surface)
                                    .cornerRadius(Theme.cornerRadiusSM)
                                    .focused($focusedField, equals: .name)
                                    .onChange(of: name) { _, newValue in
                                        let limited = CategoryLimits.limitedName(newValue)
                                        if limited != newValue { name = limited }
                                    }

                                if CategoryLimits.isNameAtLimit(name) {
                                    Text("Names can be up to \(CategoryLimits.maxNameLength) characters.")
                                        .font(.system(size: Theme.fontSizeXS))
                                        .foregroundColor(Theme.textTertiary)
                                }

                                if collision {
                                    Text("A category named \"\(name.trimmingCharacters(in: .whitespacesAndNewlines))\" already exists.")
                                        .font(.system(size: Theme.fontSizeXS))
                                        .foregroundColor(.red)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: Theme.spacingSM) {
                            Text("Description")
                                .font(.system(size: Theme.fontSizeSM, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                            TextField("What kind of notes should land here? The AI uses this to decide.", text: $definition, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(size: Theme.fontSizeMD))
                                .foregroundColor(Theme.textPrimary)
                                .padding(Theme.spacingMD)
                                .background(Theme.surface)
                                .cornerRadius(Theme.cornerRadiusSM)
                                .lineLimit(3...6)
                                .focused($focusedField, equals: .definition)
                        }

                        VStack(alignment: .leading, spacing: Theme.spacingSM) {
                            Text("Specific names (comma-separated)")
                                .font(.system(size: Theme.fontSizeSM, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                            TextField("e.g., Pocketly, Acme Co., Priya", text: $keywordsText)
                                .textFieldStyle(.plain)
                                .font(.system(size: Theme.fontSizeMD))
                                .foregroundColor(Theme.textPrimary)
                                .padding(Theme.spacingMD)
                                .background(Theme.surface)
                                .cornerRadius(Theme.cornerRadiusSM)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($focusedField, equals: .keywords)
                            Text("Optional. Any words only you’d connect to this, like a person, a company or a nickname for a place. When one shows up in a note, the note lands here.")
                                .font(.system(size: Theme.fontSizeXS))
                                .foregroundColor(Theme.textTertiary)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: Theme.fontSizeSM))
                                .foregroundColor(.red)
                        }

                        Button(action: submit) {
                            if isSubmitting {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Theme.background))
                            } else {
                                Text("Create category")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(PrimaryButtonStyle(isEnabled: canSubmit))
                        .disabled(!canSubmit)
                        .padding(.top, Theme.spacingMD)

                        Spacer(minLength: Theme.spacingXL)
                    }
                    .padding(Theme.spacingLG)
                }
            }
            .navigationTitle("New category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .interactiveDismissDisabled(isSubmitting)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                        .disabled(isSubmitting)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .foregroundColor(Theme.accent)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var collision: Bool {
        guard !trimmedName.isEmpty else { return false }
        return existingNames.contains { $0.lowercased() == trimmedName.lowercased() }
    }

    private var canSubmit: Bool {
        !isSubmitting && !trimmedName.isEmpty && !collision
    }

    private func submit() {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil

        let keywords = keywordsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let category = Category(
            name: trimmedName,
            definition: definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : definition.trimmingCharacters(in: .whitespacesAndNewlines),
            keywords: keywords.isEmpty ? nil : keywords,
            source: "user"
        )

        Task {
            do {
                let response = try await NotesService.shared.addCategories([category])
                if let newCategory = response.categories.first {
                    await saveEmoji(for: newCategory.categoryId)
                }
                await MainActor.run {
                    isSubmitting = false
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

    /// Creating a category doesn't take an emoji, so it is saved right after.
    /// 📁 is what the app shows without one, so it isn't sent. If the save
    /// fails the category still exists, so the sheet closes as usual and the
    /// emoji waits on this phone; the category list sends it when it loads.
    private func saveEmoji(for categoryId: Int) async {
        guard !emoji.isEmpty, emoji != CategoryEmoji.placeholder else { return }
        do {
            _ = try await NotesService.shared.updateCategory(
                id: categoryId,
                update: CategoryUpdateRequest(emoji: emoji)
            )
        } catch {
            CategoryEmojiStore().set(emoji, for: categoryId)
        }
    }
}

#Preview {
    NewCategoryView(existingNames: ["Work", "Personal"])
}

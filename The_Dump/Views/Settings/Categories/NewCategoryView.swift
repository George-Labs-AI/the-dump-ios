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
                            Text("Keywords (comma-separated)")
                                .font(.system(size: Theme.fontSizeSM, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                            TextField("e.g., meeting, retro, planning", text: $keywordsText)
                                .textFieldStyle(.plain)
                                .font(.system(size: Theme.fontSizeMD))
                                .foregroundColor(Theme.textPrimary)
                                .padding(Theme.spacingMD)
                                .background(Theme.surface)
                                .cornerRadius(Theme.cornerRadiusSM)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($focusedField, equals: .keywords)
                            Text("Optional — helps the AI route notes here.")
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
                    CategoryEmojiStore.setEmoji(emoji, for: newCategory.categoryId)
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
}

#Preview {
    NewCategoryView(existingNames: ["Work", "Personal"])
}

import SwiftUI

struct AddSubCategoryView: View {
    let categoryName: String
    let onAdd: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var subCategoryName: String = ""
    @State private var description: String = ""
    @State private var keywords: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showInfo: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacingLG) {
                        // Category (read-only)
                        VStack(alignment: .leading, spacing: Theme.spacingSM) {
                            Text("Category")
                                .font(.system(size: Theme.fontSizeSM, weight: .medium))
                                .foregroundColor(Theme.textPrimary)

                            HStack {
                                Text(categoryName)
                                    .font(.system(size: Theme.fontSizeMD))
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(Theme.spacingMD)
                            .background(Theme.mediumGray)
                            .cornerRadius(Theme.cornerRadiusSM)
                        }

                        // Sub-category name
                        VStack(alignment: .leading, spacing: Theme.spacingSM) {
                            Text("Sub-category name")
                                .font(.system(size: Theme.fontSizeSM, weight: .medium))
                                .foregroundColor(Theme.textPrimary)

                            TextField("e.g., onboarding", text: $subCategoryName)
                                .textFieldStyle(.plain)
                                .font(.system(size: Theme.fontSizeMD))
                                .foregroundColor(Theme.textPrimary)
                                .padding(Theme.spacingMD)
                                .background(Theme.darkGray)
                                .cornerRadius(Theme.cornerRadiusSM)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        // Description (optional)
                        VStack(alignment: .leading, spacing: Theme.spacingSM) {
                            Text("Description")
                                .font(.system(size: Theme.fontSizeSM, weight: .medium))
                                .foregroundColor(Theme.textPrimary)

                            TextField("Short description (optional)", text: $description, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(size: Theme.fontSizeMD))
                                .foregroundColor(Theme.textPrimary)
                                .padding(Theme.spacingMD)
                                .background(Theme.darkGray)
                                .cornerRadius(Theme.cornerRadiusSM)
                                .lineLimit(3...6)
                        }

                        // Keywords
                        VStack(alignment: .leading, spacing: Theme.spacingSM) {
                            Text("Keywords (comma-separated)")
                                .font(.system(size: Theme.fontSizeSM, weight: .medium))
                                .foregroundColor(Theme.textPrimary)

                            TextField("e.g., welcome, intro, first steps", text: $keywords)
                                .textFieldStyle(.plain)
                                .font(.system(size: Theme.fontSizeMD))
                                .foregroundColor(Theme.textPrimary)
                                .padding(Theme.spacingMD)
                                .background(Theme.darkGray)
                                .cornerRadius(Theme.cornerRadiusSM)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)

                            Text("Stored as {keyword1, keyword2}")
                                .font(.system(size: Theme.fontSizeXS))
                                .foregroundColor(Theme.textSecondary)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: Theme.fontSizeSM))
                                .foregroundColor(Theme.accent)
                                .padding(.top, Theme.spacingSM)
                        }

                        Spacer(minLength: Theme.spacingXL)
                    }
                    .padding(Theme.spacingLG)
                }
            }
            .navigationTitle("Add Sub-Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showInfo = true }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Spacer()
                        Button(action: addSubCategory) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.textPrimary))
                            } else {
                                Text("Add")
                            }
                        }
                        .disabled(isAddDisabled)
                        .buttonStyle(PrimaryButtonStyle(isEnabled: !isAddDisabled))
                    }
                }
            }
            .alert("About Sub-Categories", isPresented: $showInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Sub-categories help you organize notes within a category. Add keywords to help the AI automatically assign notes to this sub-category.")
            }
        }
    }

    private var isAddDisabled: Bool {
        subCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
    }

    private func addSubCategory() {
        guard !isAddDisabled else { return }

        isLoading = true
        errorMessage = nil

        let trimmedName = subCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        // Convert comma-separated keywords to PostgreSQL array format
        let keywordsArray = keywords
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let keywordsPostgres: String? = keywordsArray.isEmpty ? nil : "{\(keywordsArray.joined(separator: ", "))}"

        Task {
            do {
                try await NotesService.shared.createSubCategory(
                    categoryName: categoryName,
                    subCatName: trimmedName,
                    subCatDescription: trimmedDescription.isEmpty ? nil : trimmedDescription,
                    subCatKeywords: keywordsPostgres
                )

                await MainActor.run {
                    onAdd(trimmedName)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    AddSubCategoryView(categoryName: "Family") { name in
        print("Added sub-category: \(name)")
    }
}

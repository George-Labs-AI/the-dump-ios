import SwiftUI

struct OnboardingDefinitionsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: OnboardingViewModel
    let onBack: () -> Void
    let onComplete: () -> Void
    var isSettingsMode: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Button(action: onBack) {
                    HStack(spacing: Theme.spacingXS) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(Theme.accent)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.spacingMD)
            .padding(.vertical, Theme.spacingSM)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    // Header
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        Text(isSettingsMode ? "Define your new categories" : "Help us understand your categories")
                            .font(.system(size: Theme.fontSizeXL, weight: .bold))
                            .foregroundColor(Theme.textPrimary)

                        Text("Tell us what goes in each one. We'll use this to sort your notes.")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textSecondary)
                    }

                    // Category Cards
                    ForEach(viewModel.categories) { category in
                        CategoryDefinitionCard(
                            category: category,
                            onDefinitionChange: { newValue in
                                viewModel.updateDefinition(for: category.id, definition: newValue)
                            },
                            onKeywordsChange: { newValue in
                                viewModel.updateKeywords(for: category.id, keywords: newValue)
                            }
                        )
                    }
                }
                .padding(Theme.spacingMD)
            }

            // Footer
            VStack(spacing: Theme.spacingSM) {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.accent)
                        .multilineTextAlignment(.center)
                }

                Button(action: saveAndContinue) {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.textPrimary))
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(isSettingsMode ? "Save categories" : "Save & start dumping")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isSubmitting)

                Button(action: skipAndContinue) {
                    Text("Skip for now")
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                }
                .disabled(viewModel.isSubmitting)
            }
            .padding(Theme.spacingMD)
        }
    }

    private func saveAndContinue() {
        Task {
            let success: Bool
            if isSettingsMode {
                success = await viewModel.submitNewCategories()
            } else {
                success = await viewModel.submitCustomCategories(appState: appState)
            }
            if success {
                onComplete()
            }
        }
    }

    private func skipAndContinue() {
        Task {
            let success: Bool
            if isSettingsMode {
                success = await viewModel.skipDefinitionsFromSettings()
            } else {
                success = await viewModel.skipDefinitions(appState: appState)
            }
            if success {
                onComplete()
            }
        }
    }
}

// MARK: - Category Definition Card

private struct CategoryDefinitionCard: View {
    let category: OnboardingCategory
    let onDefinitionChange: (String) -> Void
    let onKeywordsChange: (String) -> Void

    @State private var definition: String = ""
    @State private var keywords: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMD) {
            // Category Name
            Text(category.name)
                .font(.system(size: Theme.fontSizeLG, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            // Definition Field
            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                Text("What goes here?")
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textSecondary)

                TextEditor(text: $definition)
                    .scrollContentBackground(.hidden)
                    .padding(Theme.spacingSM)
                    .frame(minHeight: 80)
                    .background(Theme.surface2)
                    .foregroundColor(Theme.textPrimary)
                    .cornerRadius(Theme.cornerRadiusSM)
                    .onChange(of: definition) { _, newValue in
                        onDefinitionChange(newValue)
                    }
            }

            // Keywords Field
            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                Text("Keywords you might use")
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textSecondary)

                TextField("e.g., meeting, project, deadline", text: $keywords)
                    .padding(Theme.spacingSM)
                    .background(Theme.surface2)
                    .foregroundColor(Theme.textPrimary)
                    .cornerRadius(Theme.cornerRadiusSM)
                    .onChange(of: keywords) { _, newValue in
                        onKeywordsChange(newValue)
                    }
            }
        }
        .padding(Theme.spacingMD)
        .background(Theme.surface)
        .cornerRadius(Theme.cornerRadius)
        .onAppear {
            definition = category.definition
            keywords = category.keywords
        }
    }
}

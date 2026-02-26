import SwiftUI

struct OnboardingCategoriesView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onBack: () -> Void
    let onContinue: () -> Void
    var isSettingsMode: Bool = false
    var existingCategories: [(name: String, count: Int)] = []

    @FocusState private var isInputFocused: Bool

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
                        Text(isSettingsMode ? "Add new categories" : "Choose 3-10 categories you'd like your notes organized into.")
                            .font(.system(size: Theme.fontSizeXL, weight: .bold))
                            .foregroundColor(Theme.textPrimary)

                        Text(isSettingsMode ? "Add categories to organize more of your notes." : "Think of these as folders. Each note will be assigned to one category.")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textSecondary)

                        if !isSettingsMode {
                            Text("You can add sub-categories within each category later.")
                                .font(.system(size: Theme.fontSizeXS))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }

                    // Text Input
                    HStack {
                        TextField("Type a category and press Enter (e.g., My Startup, Meal Planning)", text: $viewModel.categoryInput)
                            .textFieldStyle(DumpTextFieldStyle())
                            .focused($isInputFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                viewModel.addCategoryFromInput()
                            }
                    }

                    // Domain Chips
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        Text("Get suggestions from life areas:")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textSecondary)

                        FlowLayout(spacing: Theme.spacingSM) {
                            ForEach(DomainSuggestions.allDomains) { domain in
                                DomainChip(
                                    name: domain.name,
                                    isSelected: viewModel.isDomainActive(domain.id),
                                    onTap: { viewModel.toggleDomain(domain.id) }
                                )
                            }
                        }
                    }

                    // Suggestions
                    if !viewModel.availableSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.spacingSM) {
                            FlowLayout(spacing: Theme.spacingSM) {
                                ForEach(viewModel.availableSuggestions, id: \.self) { suggestion in
                                    SuggestionChip(
                                        text: suggestion,
                                        onTap: { viewModel.addSuggestion(suggestion) }
                                    )
                                }
                            }
                        }
                    }

                    // Existing Categories (Settings Mode Only)
                    if isSettingsMode && !existingCategories.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.spacingSM) {
                            Text("Existing Categories")
                                .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)

                            FlowLayout(spacing: Theme.spacingSM) {
                                ForEach(existingCategories, id: \.name) { category in
                                    ExistingCategoryChip(name: category.name, count: category.count)
                                }
                            }
                        }
                    }

                    // Your Categories (New)
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        HStack {
                            Text(isSettingsMode ? "New Categories" : "Your Categories")
                                .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)

                            Spacer()

                            Text("\(viewModel.categoryCount) \(viewModel.categoryCount == 1 ? "category" : "categories")")
                                .font(.system(size: Theme.fontSizeSM))
                                .foregroundColor(viewModel.isCategoryCountValid ? Theme.success : Theme.accent)
                        }

                        if viewModel.categories.isEmpty {
                            Text(isSettingsMode ? "New categories will appear here" : "Your categories will appear here")
                                .font(.system(size: Theme.fontSizeSM))
                                .foregroundColor(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(Theme.spacingMD)
                                .background(Theme.surface)
                                .cornerRadius(Theme.cornerRadius)
                        } else {
                            FlowLayout(spacing: Theme.spacingSM) {
                                ForEach(viewModel.categories) { category in
                                    RemovableTagChip(
                                        text: category.name,
                                        onRemove: { viewModel.removeCategory(category) }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(Theme.spacingMD)
            }

            // Footer
            VStack(spacing: Theme.spacingSM) {
                Text(viewModel.categoriesNeededMessage)
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(viewModel.isCategoryCountValid ? Theme.textSecondary : Theme.accent)

                Button(action: onContinue) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: viewModel.isCategoryCountValid))
                .disabled(!viewModel.isCategoryCountValid)
            }
            .padding(Theme.spacingMD)
        }
    }
}

// MARK: - Domain Chip

private struct DomainChip: View {
    let name: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(name)
                .font(.system(size: Theme.fontSizeSM, weight: .medium))
                .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                .padding(.horizontal, Theme.spacingSMPlus)
                .padding(.vertical, Theme.spacingSM)
                .background(isSelected ? Theme.accent : Theme.surface2)
                .cornerRadius(Theme.cornerRadiusPill)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Suggestion Chip

private struct SuggestionChip: View {
    let text: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.spacingXS) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                Text(text)
                    .font(.system(size: Theme.fontSizeSM))
            }
            .foregroundColor(Theme.accent)
            .padding(.horizontal, Theme.spacingSMPlus)
            .padding(.vertical, Theme.spacingXS)
            .background(Theme.accent.opacity(0.15))
            .cornerRadius(Theme.cornerRadiusCapture)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Removable Tag Chip

private struct RemovableTagChip: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Theme.spacingXS) {
            Text(text)
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textPrimary)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, Theme.spacingSMPlus)
        .padding(.vertical, Theme.spacingSM)
        .background(Theme.surface2)
        .cornerRadius(Theme.cornerRadiusCapture)
    }
}

// MARK: - Existing Category Chip (Read-only)

private struct ExistingCategoryChip: View {
    let name: String
    let count: Int

    var body: some View {
        HStack(spacing: Theme.spacingXS) {
            Text(name)
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textSecondary)

            Text("\(count)")
                .font(.system(size: Theme.fontSizeXS))
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, Theme.spacingXS)
                .padding(.vertical, 2)
                .background(Theme.surface2.opacity(0.5))
                .cornerRadius(Theme.cornerRadiusSM)
        }
        .padding(.horizontal, Theme.spacingSMPlus)
        .padding(.vertical, Theme.spacingSM)
        .background(Theme.surface)
        .cornerRadius(Theme.cornerRadiusCapture)
    }
}

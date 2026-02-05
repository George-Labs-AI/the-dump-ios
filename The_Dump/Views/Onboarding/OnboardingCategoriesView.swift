import SwiftUI

struct OnboardingCategoriesView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onBack: () -> Void
    let onContinue: () -> Void

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
                        Text("Choose 3-10 categories you'd like your notes organized into.")
                            .font(.system(size: Theme.fontSizeXL, weight: .bold))
                            .foregroundColor(Theme.textPrimary)

                        Text("Think of these as folders. Each note will be assigned to one category.")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textSecondary)

                        Text("You can add sub-categories within each category later.")
                            .font(.system(size: Theme.fontSizeXS))
                            .foregroundColor(Theme.textSecondary)
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

                    // Your Categories
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        HStack {
                            Text("Your Categories")
                                .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)

                            Spacer()

                            Text("\(viewModel.categoryCount) \(viewModel.categoryCount == 1 ? "category" : "categories")")
                                .font(.system(size: Theme.fontSizeSM))
                                .foregroundColor(viewModel.isCategoryCountValid ? .green : Theme.accent)
                        }

                        if viewModel.categories.isEmpty {
                            Text("Your categories will appear here")
                                .font(.system(size: Theme.fontSizeSM))
                                .foregroundColor(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(Theme.spacingMD)
                                .background(Theme.darkGray)
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
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Theme.accent : Theme.mediumGray)
                .cornerRadius(20)
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
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                Text(text)
                    .font(.system(size: Theme.fontSizeSM))
            }
            .foregroundColor(Theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.accent.opacity(0.15))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Removable Tag Chip

private struct RemovableTagChip: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textPrimary)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.mediumGray)
        .cornerRadius(16)
    }
}

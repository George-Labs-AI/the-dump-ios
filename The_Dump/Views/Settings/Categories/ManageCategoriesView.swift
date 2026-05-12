import SwiftUI

struct ManageCategoriesView: View {
    @StateObject private var viewModel = CategoryManagementViewModel()
    @State private var showNewCategory = false
    @State private var selectedCategory: CategoryListItem?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.active.isEmpty {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.textPrimary))
            } else if let error = viewModel.errorMessage, viewModel.active.isEmpty {
                ErrorState(message: error) {
                    Task { await viewModel.load() }
                }
            } else {
                content
            }

            if let toast = viewModel.toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.background)
                        .padding(.horizontal, Theme.spacingMD)
                        .padding(.vertical, Theme.spacingSM)
                        .background(Theme.textPrimary)
                        .cornerRadius(Theme.cornerRadiusSM)
                        .padding(.bottom, Theme.spacingXL)
                }
                .transition(.opacity)
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await viewModel.load() }
        .sheet(isPresented: $showNewCategory, onDismiss: {
            Task { await viewModel.load() }
        }) {
            NewCategoryView(existingNames: viewModel.active.map { $0.name })
        }
        .navigationDestination(item: $selectedCategory) { item in
            CategoryDetailView(categoryId: item.id) { didChange in
                if didChange {
                    Task { await viewModel.load() }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        List {
            // Cap meter
            Section {
                CapMeterRow(used: viewModel.active.count, cap: CategoryLimits.maxActiveCategories)
                    .listRowBackground(Theme.surface)
                    .listRowInsets(EdgeInsets(top: Theme.spacingSM, leading: Theme.spacingMD, bottom: Theme.spacingSM, trailing: Theme.spacingMD))
            }

            // Helper row
            if !viewModel.helperDismissed {
                Section {
                    HelperRow {
                        withAnimation { viewModel.helperDismissed = true }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: Theme.spacingMD, bottom: Theme.spacingSM, trailing: Theme.spacingMD))
                }
            }

            // Active
            Section {
                ForEach(viewModel.active) { item in
                    Button {
                        selectedCategory = item
                    } label: {
                        CategoryRow(item: item)
                    }
                    .listRowBackground(Theme.surface)
                }

                Button {
                    showNewCategory = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(viewModel.atCap ? Theme.textTertiary : Theme.accent)
                        Text(viewModel.atCap ? "At maximum" : "Add category")
                            .foregroundColor(viewModel.atCap ? Theme.textTertiary : Theme.accent)
                        Spacer()
                    }
                }
                .disabled(viewModel.atCap)
                .listRowBackground(Theme.surface)
            } header: {
                Text("Active")
                    .sectionLabel()
                    .foregroundColor(Theme.textSecondary)
            }

            // Archived
            if !viewModel.archived.isEmpty {
                Section {
                    ForEach(viewModel.archived) { item in
                        Button {
                            selectedCategory = item
                        } label: {
                            CategoryRow(item: item)
                                .opacity(0.7)
                        }
                        .listRowBackground(Theme.surface)
                    }
                } header: {
                    Text("Archived")
                        .sectionLabel()
                        .foregroundColor(Theme.textSecondary)
                }
            }

            // Recently deleted
            if !viewModel.recentlyDeleted.isEmpty {
                Section {
                    ForEach(viewModel.recentlyDeleted) { item in
                        HStack {
                            Text(CategoryEmojiStore.emoji(for: item.id))
                            Text(item.name)
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("\(item.noteCount) notes")
                                .font(.system(size: Theme.fontSizeSM))
                                .foregroundColor(Theme.textTertiary)
                        }
                        .listRowBackground(Theme.surface)
                    }
                } header: {
                    Text("Recently deleted")
                        .sectionLabel()
                        .foregroundColor(Theme.textSecondary)
                } footer: {
                    Text("Deleted categories are kept for 30 days.")
                        .font(.system(size: Theme.fontSizeXS))
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.load()
        }
    }
}

// MARK: - Row

private struct CategoryRow: View {
    let item: CategoryListItem

    var body: some View {
        HStack(spacing: Theme.spacingSMPlus) {
            Text(CategoryEmojiStore.emoji(for: item.id))
                .font(.system(size: 22))
                .frame(width: 32, height: 32)
                .background(Theme.surface2)
                .cornerRadius(Theme.cornerRadiusCatIcon)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.spacingXS) {
                    Text(item.name)
                        .font(.system(size: Theme.fontSizeMD, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    if item.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textTertiary)
                    }
                }

                Text(subtitle)
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts: [String] = ["\(item.noteCount) \(item.noteCount == 1 ? "note" : "notes")"]
        if item.subCatCount > 0 {
            parts.append("\(item.subCatCount) sub")
        }
        if item.isLocked {
            parts.append("\(item.inProcessCount) processing")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Cap meter

private struct CapMeterRow: View {
    let used: Int
    let cap: Int

    private var progress: Double {
        guard cap > 0 else { return 0 }
        return min(1.0, Double(used) / Double(cap))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack {
                Text("Categories")
                    .font(.system(size: Theme.fontSizeSM, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text("\(used) / \(cap)")
                    .font(.system(size: Theme.fontSizeSM, weight: .semibold))
                    .foregroundColor(used >= cap ? Theme.warning : Theme.textPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.surface2)
                    Capsule()
                        .fill(used >= cap ? Theme.warning : Theme.textPrimary)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Helper row

private struct HelperRow: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.spacingSM) {
            Image(systemName: "sparkles")
                .foregroundColor(Theme.accent)
                .padding(.top, 2)

            Text("These are the buckets the AI sorts new notes into. Edit a category to refine its description and keywords.")
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: Theme.spacingSM)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)
                    .padding(6)
            }
        }
        .padding(Theme.spacingMD)
        .background(Theme.accentSubtle)
        .cornerRadius(Theme.cornerRadius)
    }
}

// MARK: - Error state

private struct ErrorState: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Theme.spacingMD) {
            Text("Failed to load categories")
                .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Text(message)
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try Again", action: onRetry)
                .foregroundColor(Theme.accent)
        }
        .padding(Theme.spacingMD)
    }
}

#Preview {
    NavigationStack {
        ManageCategoriesView()
    }
}

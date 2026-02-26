import SwiftUI

struct CategoryManagementView: View {
    @State private var isLoading = true
    @State private var existingCategories: [(name: String, count: Int)] = []
    @State private var errorMessage: String?
    @State private var showAddCategories = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.textPrimary))
            } else if let error = errorMessage {
                VStack(spacing: Theme.spacingMD) {
                    Text("Failed to load categories")
                        .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    Text(error)
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)

                    Button("Try Again") {
                        Task {
                            await loadCategories()
                        }
                    }
                    .foregroundColor(Theme.accent)
                }
                .padding(Theme.spacingMD)
            } else {
                VStack(spacing: 0) {
                    if existingCategories.isEmpty {
                        VStack(spacing: Theme.spacingMD) {
                            Text("No categories yet")
                                .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)

                            Text("Add categories to organize your notes.")
                                .font(.system(size: Theme.fontSizeSM))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        List {
                            Section {
                                ForEach(existingCategories, id: \.name) { category in
                                    HStack {
                                        Text(category.name)
                                            .foregroundColor(Theme.textPrimary)
                                        Spacer()
                                        Text("\(category.count) \(category.count == 1 ? "note" : "notes")")
                                            .foregroundColor(Theme.textSecondary)
                                            .font(.system(size: Theme.fontSizeSM))
                                    }
                                    .listRowBackground(Theme.surface)
                                }
                            } header: {
                                Text("Your Categories")
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.insetGrouped)
                    }

                    // Add Categories Button
                    Button(action: { showAddCategories = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Categories")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(Theme.spacingMD)
                }
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await loadCategories()
        }
        .sheet(isPresented: $showAddCategories) {
            SettingsCategoryFlowView(
                existingCategories: existingCategories,
                onComplete: {
                    showAddCategories = false
                    Task {
                        await loadCategories()
                    }
                }
            )
        }
    }

    private func loadCategories() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await NotesService.shared.fetchCounts()
            existingCategories = response.categories
                .map { (name: $0.key, count: $0.value) }
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        CategoryManagementView()
    }
}

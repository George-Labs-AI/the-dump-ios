import SwiftUI

// Sheets for the notes list's select mode: confirm a delete by typing the
// number of notes (as on the web), and pick a category or a type for every
// selected note. Each sheet runs its action, then closes; a failure shows at
// the top of the list, which keeps the selection.

private func notesPhrase(_ count: Int) -> String {
    count == 1 ? "1 note" : "\(count) notes"
}

struct BulkDeleteConfirmView: View {
    @Environment(\.dismiss) private var dismiss
    let noteCount: Int
    let onConfirm: () async -> Bool

    @State private var typed: String = ""
    @State private var isWorking = false

    private var canDelete: Bool {
        BulkDeleteConfirmation.matches(typed: typed, count: noteCount) && !isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("You are about to delete \(notesPhrase(noteCount)). This can't be undone.")
                        .foregroundColor(Theme.textPrimary)
                    Text("Type the number of notes to confirm:")
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                    TextField("Type the number here", text: $typed)
                        .keyboardType(.numberPad)
                        .accessibilityLabel("Number of notes to delete")
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Delete notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isWorking)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Delete", role: .destructive) {
                            isWorking = true
                            Task {
                                _ = await onConfirm()
                                dismiss()
                            }
                        }
                        .foregroundColor(canDelete ? Theme.destructive : Theme.textSecondary)
                        .disabled(!canDelete)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(isWorking)
    }
}

struct BulkCategoryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let noteCount: Int
    /// The category this list shows, if any; picking it would change nothing.
    let currentCategoryId: Int?
    let onPick: (CategoryResponse) async -> Bool

    @State private var categories: [CategoryResponse] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && categories.isEmpty {
                    ProgressView("Loading…")
                        .foregroundColor(Theme.textPrimary)
                } else if let loadError, categories.isEmpty {
                    VStack(spacing: Theme.spacingMD) {
                        Label(loadError, systemImage: "exclamationmark.circle")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await load() }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(Theme.spacingLG)
                } else if categories.isEmpty {
                    Text("You don't have any active categories.")
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                        .padding(Theme.spacingLG)
                } else {
                    List {
                        Section {
                            ForEach(categories, id: \.categoryId) { category in
                                Button {
                                    isWorking = true
                                    Task {
                                        _ = await onPick(category)
                                        dismiss()
                                    }
                                } label: {
                                    HStack {
                                        Text(category.name)
                                            .foregroundColor(Theme.textPrimary)
                                        Spacer()
                                        if category.categoryId == currentCategoryId {
                                            Text("Current")
                                                .font(.system(size: Theme.fontSizeXS))
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .disabled(isWorking || category.categoryId == currentCategoryId)
                                .listRowBackground(Theme.surface)
                            }
                        } header: {
                            Text("Move \(notesPhrase(noteCount)) to")
                                .sectionLabel()
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle("Change category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isWorking)
                }
                if isWorking {
                    ToolbarItem(placement: .confirmationAction) {
                        ProgressView()
                    }
                }
            }
        }
        .interactiveDismissDisabled(isWorking)
        .task { await load() }
    }

    /// Only active categories: the server refuses a blank or archived one.
    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            categories = try await NotesService.shared.fetchCategories().categories
                .filter { $0.archived != true && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            loadError = error.localizedDescription
        }
    }
}

struct BulkTypePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var catalog = NoteTypeCatalog.shared
    let noteCount: Int
    let onPick: (String) async -> Bool

    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(catalog.types, id: \.self) { type in
                        Button {
                            isWorking = true
                            Task {
                                _ = await onPick(type)
                                dismiss()
                            }
                        } label: {
                            Text(type)
                                .foregroundColor(Theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .disabled(isWorking)
                        .listRowBackground(Theme.surface)
                    }
                } header: {
                    Text("Give \(notesPhrase(noteCount)) the type")
                        .sectionLabel()
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Change type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isWorking)
                }
                if isWorking {
                    ToolbarItem(placement: .confirmationAction) {
                        ProgressView()
                    }
                }
            }
        }
        .interactiveDismissDisabled(isWorking)
        .task { await catalog.refresh() }
    }
}

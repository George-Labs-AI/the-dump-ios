import SwiftUI

// The actual list of notes. Displays note previews in a scrollable list, handles pagination, handles search within the filtered set. Tapping a note navigates to NoteDetailView.

struct NotesListView: View {
    private let title: String
    @StateObject private var viewModel: NotesListViewModel
    @State private var searchText: String = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var showAddSubCategory: Bool = false
    @State private var noteToDelete: NotePreview?
    @State private var showDeleteConfirmation: Bool = false

    init(title: String, filter: NotesListViewModel.Filter) {
        self.title = title
        _viewModel = StateObject(wrappedValue: NotesListViewModel(filter: filter))
    }

    /// Whether this view is showing a category (and should display subcategory UI)
    private var isCategoryFilter: Bool {
        viewModel.categoryName != nil
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            Group {
                if viewModel.isLoadingInitial && viewModel.notes.isEmpty {
                    ProgressView("Loading…")
                        .foregroundColor(Theme.textPrimary)
                } else if let error = viewModel.errorMessage, viewModel.notes.isEmpty {
                    VStack(spacing: Theme.spacingMD) {
                        Text(error)
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.accent)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            Task { await viewModel.refresh() }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(Theme.spacingLG)
                } else {
                    List {
                        if let error = viewModel.errorMessage, !viewModel.notes.isEmpty {
                            Section {
                                Text(error)
                                    .font(.system(size: Theme.fontSizeSM))
                                    .foregroundColor(Theme.accent)
                            }
                            .listRowBackground(Theme.surface)
                        }

                        // Sub-category filter section (only for category views)
                        if isCategoryFilter {
                            Section {
                                SubCategoryFilterRow(
                                    availableSubCategories: viewModel.availableSubCategories,
                                    selectedSubCategory: $viewModel.selectedSubCategory,
                                    onFilterChange: {
                                        Task { await viewModel.refresh() }
                                    },
                                    onAddTapped: {
                                        showAddSubCategory = true
                                    }
                                )
                            }
                            .listRowBackground(Theme.surface)
                            .listRowInsets(EdgeInsets(top: Theme.spacingSM, leading: Theme.spacingMD, bottom: Theme.spacingSM, trailing: Theme.spacingSM))
                        }

                        ForEach(viewModel.notes) { note in
                            NavigationLink {
                                NoteDetailView(noteID: note.id)
                            } label: {
                                NoteListRowView(note: note)
                            }
                            .listRowBackground(Theme.surface)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    noteToDelete = note
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .onAppear {
                                Task { await viewModel.loadMoreIfNeeded(currentItem: note) }
                            }
                        }
                        
                        if viewModel.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.textSecondary))
                                Spacer()
                            }
                            .listRowBackground(Theme.background)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            // Only load once per navigation
            if viewModel.notes.isEmpty {
                await viewModel.refresh()
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search notes")
        .onChange(of: searchText) { _, newValue in
            // Cancel previous debounce task
            searchTask?.cancel()

            // Debounce: wait 300ms before triggering search
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }

                viewModel.searchQuery = newValue
                await viewModel.refresh()
            }
        }
        .alert("Delete Note", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                noteToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let note = noteToDelete {
                    Task { await viewModel.deleteNote(noteId: note.id) }
                    noteToDelete = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete this note? This action cannot be undone.")
        }
        .sheet(isPresented: $showAddSubCategory) {
            if let categoryName = viewModel.categoryName {
                AddSubCategoryView(categoryName: categoryName) { newSubCatName in
                    viewModel.addSubCategoryToList(newSubCatName)
                }
            }
        }
    }
}

// MARK: - Sub-Category Filter Row

private struct SubCategoryFilterRow: View {
    let availableSubCategories: [String]
    @Binding var selectedSubCategory: String?
    let onFilterChange: () -> Void
    let onAddTapped: () -> Void

    @State private var showInfoPopover: Bool = false

    private let infoText = "Add sub-categories within categories. Each note in the category will be checked to see if it matches the sub-category description, and added automatically to the sub-category if there's a strong match. Each note can be assigned to up to 3 sub-categories."

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            // Filter pills row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.spacingSM) {
                    // "All" pill — always first
                    FilterPill(
                        label: "All",
                        isActive: selectedSubCategory == nil,
                        onTap: {
                            selectedSubCategory = nil
                            onFilterChange()
                        }
                    )

                    ForEach(availableSubCategories, id: \.self) { subCat in
                        FilterPill(
                            label: subCat,
                            isActive: selectedSubCategory == subCat,
                            onTap: {
                                selectedSubCategory = subCat
                                onFilterChange()
                            }
                        )
                    }

                    // Add sub-category pill
                    Button(action: onAddTapped) {
                        HStack(spacing: Theme.spacingXS) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Add")
                                .font(.system(size: Theme.fontSizeXS))
                        }
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, Theme.spacingSMPlus)
                        .padding(.vertical, Theme.spacingSM)
                        .background(Theme.accent.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    // Info button
                    Button(action: { showInfoPopover = true }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showInfoPopover, arrowEdge: .top) {
                        Text(infoText)
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textPrimary)
                            .padding(Theme.spacingMD)
                            .frame(maxWidth: 280)
                            .background(Theme.surface)
                            .presentationCompactAdaptation(.popover)
                    }
                }
            }
        }
    }
}

// MARK: - Filter Pill

private struct FilterPill: View {
    let label: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: Theme.fontSizeSM, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? Theme.background : Theme.textPrimary)
                .padding(.horizontal, Theme.spacingSMPlus)
                .padding(.vertical, Theme.spacingSM)
                .background(isActive ? Theme.textPrimary : Theme.surface2)
                .clipShape(Capsule())
                .lineLimit(1)
        }
        .buttonStyle(.plain)
    }
}

private struct NoteListRowView: View {
    let note: NotePreview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(mediaTypeEmoji())
                    .font(.system(size: 14))
                Text(displayTitle())
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
            }
            
            let snippet = derivedSnippet()
            if !snippet.isEmpty {
                Text(snippet)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 8) {
                if let modified = formattedDate(note.note_content_modified) {
                    Text(modified)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }

                if let category = note.category_name, !category.isEmpty {
                    Text(category)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(.vertical, Theme.spacingSM)
    }

    private func displayTitle() -> String {
        if let title = note.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }

        let lines = note.preview
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return lines.first ?? "Untitled"
    }

    private func mediaTypeEmoji() -> String {
        switch note.mime_type?.lowercased() {
        case "image":    return "📷"
        case "voice":    return "🎤"
        case "text":     return "✏️"
        case "document": return "📤"
        default:         return "✏️"
        }
    }

    private func derivedSnippet() -> String {
        let trimmed = note.preview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        let title = displayTitle()
        guard title != "Untitled" else { return trimmed }

        if trimmed.hasPrefix(title) {
            let remainder = trimmed.dropFirst(title.count)
            return remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return trimmed
    }
    
    private func formattedDate(_ iso: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return nil }
        
        let out = DateFormatter()
        out.locale = .current
        out.dateStyle = .medium
        out.timeStyle = .none
        return out.string(from: date)
    }
}

#Preview {
    NavigationStack {
        NotesListView(title: "Work", filter: .category(name: "Work"))
    }
}

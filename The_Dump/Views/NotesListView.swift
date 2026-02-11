import SwiftUI

// The actual list of notes. Displays note previews in a scrollable list, handles pagination, handles search within the filtered set. Tapping a note navigates to NoteDetailView.

struct NotesListView: View {
    private let title: String
    @StateObject private var viewModel: NotesListViewModel
    @State private var searchText: String = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var showAddSubCategory: Bool = false

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
                            .listRowBackground(Theme.darkGray)
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
                            .listRowBackground(Theme.darkGray)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }

                        ForEach(viewModel.notes) { note in
                            NavigationLink {
                                NoteDetailView(noteID: note.id)
                            } label: {
                                NoteListRowView(note: note)
                            }
                            .listRowBackground(Theme.darkGray)
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
        HStack(spacing: Theme.spacingSM) {
            // Dropdown for selecting sub-category
            Menu {
                Button("All Sub-Categories") {
                    selectedSubCategory = nil
                    onFilterChange()
                }

                if !availableSubCategories.isEmpty {
                    Divider()

                    ForEach(availableSubCategories, id: \.self) { subCat in
                        Button(subCat) {
                            selectedSubCategory = subCat
                            onFilterChange()
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedSubCategory ?? "Sub-category")
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.horizontal, Theme.spacingSM)
                .padding(.vertical, 6)
                .background(Theme.mediumGray)
                .cornerRadius(Theme.cornerRadiusSM)
            }

            // Clear filter button (only shown when a filter is active)
            if selectedSubCategory != nil {
                Button {
                    selectedSubCategory = nil
                    onFilterChange()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Spacer()

            // Add sub-category button and info button grouped together
            HStack(spacing: Theme.spacingSM) {
                Button(action: onAddTapped) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.accent)

                        Text("add sub-category")
                            .font(.system(size: Theme.fontSizeXS))
                            .foregroundColor(Theme.accent)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Info button with popover
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
                        .background(Theme.darkGray)
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
    }
}

private struct NoteListRowView: View {
    let note: NotePreview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayTitle())
                .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
            
            let snippet = derivedSnippet()
            if !snippet.isEmpty {
                Text(snippet)
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 8) {
                if let modified = formattedDate(note.note_content_modified) {
                    Text(modified)
                        .font(.system(size: Theme.fontSizeXS))
                        .foregroundColor(Theme.textSecondary)
                }
                
                if let category = note.category_name, !category.isEmpty {
                    Text(category)
                        .font(.system(size: Theme.fontSizeXS))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(.vertical, 8)
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

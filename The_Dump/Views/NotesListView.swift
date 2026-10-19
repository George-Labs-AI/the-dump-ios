import SwiftUI

// The actual list of notes. Displays note previews in a scrollable list, handles pagination, handles search within the filtered set. Tapping a note navigates to NoteDetailView.

struct NotesListView: View {
    @EnvironmentObject private var recategorizationTracker: CategoryRecategorizationTracker

    private let title: String
    private let categoryIsArchived: Bool
    private let categoryNoteCount: Int?
    @StateObject private var viewModel: NotesListViewModel
    @State private var searchText: String = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var showAddSubCategory: Bool = false
    @State private var noteToDelete: NotePreview?
    @State private var showDeleteConfirmation: Bool = false
    @State private var actionErrorMessage: String?
    @State private var isStartingRecategorize: Bool = false
    @State private var showBulkDelete: Bool = false
    @State private var showBulkCategoryPicker: Bool = false
    @State private var showBulkTypePicker: Bool = false
    /// How many notes the open bulk sheet acts on, fixed when it opens so the
    /// sheet doesn't change while the action clears the selection.
    @State private var bulkNoteCount: Int = 0

    init(
        title: String,
        filter: NotesListViewModel.Filter,
        categoryIsArchived: Bool = false,
        categoryNoteCount: Int? = nil
    ) {
        self.title = title
        self.categoryIsArchived = categoryIsArchived
        self.categoryNoteCount = categoryNoteCount
        _viewModel = StateObject(wrappedValue: NotesListViewModel(filter: filter))
    }

    /// Whether this view is showing a category (and should display subcategory UI)
    private var isCategoryFilter: Bool {
        viewModel.categoryName != nil
    }

    private var isArchivedCategoryRecategorizing: Bool {
        guard categoryIsArchived, let categoryId = viewModel.categoryId else { return false }
        return isStartingRecategorize || recategorizationTracker.isRecategorizing(categoryId: categoryId)
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
                                VStack(alignment: .leading, spacing: Theme.spacingSM) {
                                    SubCategoryFilterRow(
                                        pills: viewModel.subCategoryPills,
                                        selectedSubCategory: $viewModel.selectedSubCategory,
                                        isArchivedCategory: categoryIsArchived,
                                        isRecategorizingArchivedCategory: isArchivedCategoryRecategorizing,
                                        onFilterChange: {
                                            Task { await viewModel.refresh(reloadingSubCategories: false) }
                                        },
                                        onAddTapped: {
                                            showAddSubCategory = true
                                        },
                                        onRecategorizeTapped: {
                                            Task { await startRecategorizingArchivedCategory() }
                                        }
                                    )

                                    if let actionErrorMessage {
                                        Text(actionErrorMessage)
                                            .font(.system(size: Theme.fontSizeSM))
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .listRowBackground(Theme.surface)
                            .listRowInsets(EdgeInsets(top: Theme.spacingSM, leading: Theme.spacingMD, bottom: Theme.spacingSM, trailing: Theme.spacingSM))
                        }

                        ForEach(viewModel.notes) { note in
                            noteRow(note)
                                .listRowBackground(Theme.surface)
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
        .navigationTitle(viewModel.isSelecting ? selectionTitle : title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(viewModel.isSelecting)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isSelecting {
                    Button("Done") {
                        viewModel.stopSelecting()
                    }
                    .fontWeight(.semibold)
                } else if !viewModel.notes.isEmpty {
                    Button("Select") {
                        viewModel.startSelecting()
                    }
                }
            }
            if viewModel.isSelecting {
                ToolbarItemGroup(placement: .bottomBar) {
                    bulkActionBar
                }
            }
        }
        .toolbar(viewModel.isSelecting ? .hidden : .automatic, for: .tabBar)
        .task {
            // Only load once per navigation
            if viewModel.notes.isEmpty {
                await viewModel.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .categoryRecategorizationDidFinish)) { notification in
            guard let updatedCategoryId = notification.userInfo?["categoryId"] as? Int,
                  updatedCategoryId == viewModel.categoryId else { return }
            Task { await viewModel.refresh() }
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
                await viewModel.refresh(reloadingSubCategories: false)
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
        .sheet(isPresented: $showBulkDelete) {
            BulkDeleteConfirmView(noteCount: bulkNoteCount) {
                await viewModel.deleteSelected()
            }
        }
        .sheet(isPresented: $showBulkCategoryPicker) {
            BulkCategoryPickerView(
                noteCount: bulkNoteCount,
                currentCategoryId: viewModel.categoryId
            ) { category in
                await viewModel.moveSelected(toCategory: category)
            }
        }
        .sheet(isPresented: $showBulkTypePicker) {
            BulkTypePickerView(noteCount: bulkNoteCount) { type in
                await viewModel.changeTypeOfSelected(to: type)
            }
        }
    }

    private var selectionTitle: String {
        let count = viewModel.selectedNotes.count
        return count == 1 ? "1 selected" : "\(count) selected"
    }

    /// A note row. In select mode tapping picks the note; a stack row can't
    /// be picked (same as the web) and says why. Otherwise a stack opens its
    /// notes and a note opens the note.
    @ViewBuilder
    private func noteRow(_ note: NotePreview) -> some View {
        if viewModel.isSelecting {
            let isSelected = viewModel.selectedNoteIDs.contains(note.id)
            Button {
                viewModel.toggleSelection(note)
            } label: {
                HStack(spacing: Theme.spacingSMPlus) {
                    Image(systemName: note.isStack ? "circle.dashed" : (isSelected ? "checkmark.circle.fill" : "circle"))
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        NoteListRowView(note: note)
                        if note.isStack {
                            Text("Open the stack to work with its notes.")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(note.isStack)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else if note.isStack, let stackId = note.stack_id {
            NavigationLink {
                StackDetailView(stackId: stackId) {
                    Task { await viewModel.refresh() }
                }
            } label: {
                NoteListRowView(note: note)
            }
            // Swipe-to-delete would delete only the note that stands for the
            // stack, so a stack row offers Unstack instead.
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    Task { await viewModel.unstack(stackId: stackId) }
                } label: {
                    Label("Unstack", systemImage: "square.stack.3d.up.slash")
                }
                .tint(Theme.textSecondary)
            }
        } else {
            NavigationLink {
                NoteDetailView(noteID: note.id)
            } label: {
                NoteListRowView(note: note)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    noteToDelete = note
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    /// Bottom bar in select mode. Stack needs 2 or more notes; the others 1.
    @ViewBuilder
    private var bulkActionBar: some View {
        let count = viewModel.selectedNotes.count
        let busy = viewModel.isPerformingBulkAction

        Button("Stack") {
            Task { await viewModel.stackSelected() }
        }
        .disabled(!viewModel.canStackSelection || busy)

        Spacer()

        Button("Category") {
            bulkNoteCount = count
            showBulkCategoryPicker = true
        }
        .disabled(count == 0 || busy)

        Spacer()

        Button("Type") {
            bulkNoteCount = count
            showBulkTypePicker = true
        }
        .disabled(count == 0 || busy)

        Spacer()

        Button("Delete", role: .destructive) {
            bulkNoteCount = count
            showBulkDelete = true
        }
        .disabled(count == 0 || busy)
    }

    private func startRecategorizingArchivedCategory() async {
        guard categoryIsArchived else { return }
        guard let categoryId = viewModel.categoryId, let categoryName = viewModel.categoryName else { return }
        guard !isArchivedCategoryRecategorizing else { return }

        actionErrorMessage = nil
        isStartingRecategorize = true
        defer { isStartingRecategorize = false }

        do {
            let response = try await NotesService.shared.startRecategorize(
                scope: .category,
                categoryId: categoryId
            )
            recategorizationTracker.startTracking(
                jobId: response.jobId,
                categoryId: categoryId,
                categoryName: categoryName,
                noteCount: categoryNoteCount
            )
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Sub-Category Filter Row

private struct SubCategoryFilterRow: View {
    let pills: [SubCategoryPill]
    @Binding var selectedSubCategory: String?
    let isArchivedCategory: Bool
    let isRecategorizingArchivedCategory: Bool
    let onFilterChange: () -> Void
    let onAddTapped: () -> Void
    let onRecategorizeTapped: () -> Void

    @State private var showInfoPopover: Bool = false
    @State private var showRecategorizeConfirmation: Bool = false

    private var infoText: String {
        if isArchivedCategory {
            return "This category is archived, so you can't add new sub-categories here. You can still filter by the existing ones or re-categorize the archived notes into active categories."
        }

        return "Add sub-categories within categories. Each note in the category will be checked to see if it matches the sub-category description, and added automatically to the sub-category if there's a strong match. Each note can be assigned to up to 3 sub-categories."
    }

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

                    ForEach(pills) { pill in
                        FilterPill(
                            label: pill.name,
                            count: pill.count,
                            isActive: selectedSubCategory == pill.name,
                            onTap: {
                                selectedSubCategory = pill.name
                                onFilterChange()
                            }
                        )
                    }

                    if isArchivedCategory {
                        if isRecategorizingArchivedCategory {
                            Text("Currently recategorizing past notes into new categories.")
                                .font(.system(size: Theme.fontSizeXS, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal, Theme.spacingSMPlus)
                                .padding(.vertical, Theme.spacingSM)
                                .background(Theme.surface2)
                                .clipShape(Capsule())
                        } else {
                            Button {
                                showRecategorizeConfirmation = true
                            } label: {
                                HStack(spacing: Theme.spacingXS) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text("Recategorize all notes in this category")
                                        .font(.system(size: Theme.fontSizeXS))
                                }
                                .foregroundColor(Theme.accent)
                                .padding(.horizontal, Theme.spacingSMPlus)
                                .padding(.vertical, Theme.spacingSM)
                                .background(Theme.accent.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .alert("Re-categorize all notes in this category?", isPresented: $showRecategorizeConfirmation) {
                                Button("Cancel", role: .cancel) {}
                                Button("Re-categorize") {
                                    onRecategorizeTapped()
                                }
                            } message: {
                                Text("Are you sure? Past notes in this archived category may move into different active categories.")
                            }
                        }
                    } else {
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
                    }

                    // Info button
                    Button {
                        showInfoPopover = true
                    } label: {
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
    var count: Int? = nil
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.spacingXS) {
                Text(label)
                    .font(.system(size: Theme.fontSizeSM, weight: isActive ? .semibold : .regular))
                if let count {
                    Text("\(count)")
                        .font(.system(size: Theme.fontSizeXS, weight: .semibold))
                        .opacity(0.7)
                }
            }
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

/// One note in a list. Also used for the notes inside a stack.
struct NoteListRowView: View {
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

            if let stackLabel = note.stackLabel {
                Label(stackLabel, systemImage: "square.stack.3d.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, Theme.spacingSM)
                    .padding(.vertical, 3)
                    .background(Theme.surface2)
                    .clipShape(Capsule())
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

                if let author = note.displayAuthor {
                    Text("from \(author)")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
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
        guard let mime = note.mime_type?.lowercased() else { return "✏️" }
        if mime.hasPrefix("image") { return "📷" }
        if mime.hasPrefix("audio") || mime.hasPrefix("voice") { return "🎤" }
        if mime.hasPrefix("text") { return "✏️" }
        if mime.hasPrefix("document") || mime.hasPrefix("application") { return "📤" }
        return "✏️"
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
        NotesListView(title: "Work", filter: .category(id: 42, name: "Work"))
    }
}

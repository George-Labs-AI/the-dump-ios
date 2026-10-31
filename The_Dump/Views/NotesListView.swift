import SwiftUI

// The actual list of notes (Paper, 03 Category). Displays note previews in a scrollable list grouped by date, handles pagination, handles search within the filtered set. Tapping a note navigates to NoteDetailView.

struct NotesListView: View {
    @EnvironmentObject private var recategorizationTracker: CategoryRecategorizationTracker

    private let title: String
    /// Categories only: shown before the name in the headline.
    private let emoji: String?
    /// The screen this one was opened from, shown in the top bar's back button.
    private let backTitle: String
    private let categoryIsArchived: Bool
    private let categoryNoteCount: Int?
    @StateObject private var viewModel: NotesListViewModel
    /// This phone's captures that were organized and not yet opened: their
    /// rows say "Just landed".
    @StateObject private var pendingNotes = PendingNotesViewModel()
    @State private var searchText: String = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var showAddSubCategory: Bool = false
    @State private var showSubCategoryInfo: Bool = false
    @State private var showRecategorizeConfirmation: Bool = false
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
        emoji: String? = nil,
        backTitle: String = "Browse",
        categoryIsArchived: Bool = false,
        categoryNoteCount: Int? = nil
    ) {
        self.title = title
        self.emoji = emoji
        self.backTitle = backTitle
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

    private var headline: String {
        guard let emoji = emoji?.trimmingCharacters(in: .whitespacesAndNewlines), !emoji.isEmpty else { return title }
        return "\(emoji) \(title)"
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            noteList
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        // The bar is hidden, so nothing shows; this sets the screen's
        // hidesBackButton, which stops the edge swipe back (TopBar.swift)
        // while notes are selected, as the system back button used to.
        .navigationBarBackButtonHidden(viewModel.isSelecting)
        // Not shown here; it names this screen in the next one's back menu
        // and for VoiceOver.
        .navigationTitle(title)
        // The app draws its own tab bar on the two root screens only; the
        // system one stays hidden here too (MainTabView).
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.isSelecting {
                bulkActionBar
            }
        }
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
        .alert("Sub-categories", isPresented: $showSubCategoryInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(subCategoryInfoText)
        }
        .alert("Re-categorize all notes in this category?", isPresented: $showRecategorizeConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Re-categorize") {
                Task { await startRecategorizingArchivedCategory() }
            }
        } message: {
            Text("Are you sure? Past notes in this archived category may move into different active categories.")
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

    // MARK: - Top bar

    /// "‹ Browse" and "•••"; while selecting, the count and Done instead.
    @ViewBuilder
    private var topBar: some View {
        if viewModel.isSelecting {
            HStack {
                Text(selectionTitle)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                Spacer()
                Button("Done") {
                    viewModel.stopSelecting()
                }
                .buttonStyle(TDTextLinkStyle(color: Theme.textPrimary, size: 16))
            }
            .frame(height: 44)
            .padding(.horizontal, Theme.screenH)
        } else {
            TDTopBar(backTitle: backTitle) {
                // Only when the menu has something in it (see menuItems).
                if isCategoryFilter || !viewModel.notes.isEmpty {
                    Menu {
                        menuItems
                    } label: {
                        TDMoreLabel()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var menuItems: some View {
        if !viewModel.notes.isEmpty {
            Button {
                viewModel.startSelecting()
            } label: {
                Label("Select", systemImage: "checkmark.circle")
            }
        }
        if isCategoryFilter {
            if categoryIsArchived {
                Button {
                    showRecategorizeConfirmation = true
                } label: {
                    Label("Re-categorize all notes", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(isArchivedCategoryRecategorizing)
            } else {
                Button {
                    showAddSubCategory = true
                } label: {
                    Label("Add sub-category", systemImage: "plus")
                }
            }
            Button {
                showSubCategoryInfo = true
            } label: {
                Label("About sub-categories", systemImage: "info.circle")
            }
        }
    }

    private var subCategoryInfoText: String {
        if categoryIsArchived {
            return "This category is archived, so you can't add new sub-categories here. You can still filter by the existing ones or re-categorize the archived notes into active categories."
        }
        return "Add sub-categories within categories. Each note in the category will be checked to see if it matches the sub-category description, and added automatically to the sub-category if there's a strong match. Each note can be assigned to up to 3 sub-categories."
    }

    private var selectionTitle: String {
        let count = viewModel.selectedNotes.count
        return count == 1 ? "1 selected" : "\(count) selected"
    }

    // MARK: - List

    private var noteList: some View {
        List {
            Group {
                Text(headline)
                    .tdHeadline()
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, Theme.spacingSM)
                    .padding(.bottom, Theme.spacingLG)

                searchField

                if isCategoryFilter {
                    subCategoryChips
                }

                if categoryIsArchived {
                    Text(isArchivedCategoryRecategorizing
                         ? "Re-categorizing these notes into your active categories."
                         : "This category is archived.")
                        .tdCaption()
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, Theme.spacingSM)
                }

                if let message = actionErrorMessage ?? (viewModel.notes.isEmpty ? nil : viewModel.errorMessage) {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textPrimary)
                        .padding(.top, Theme.spacingSM)
                }

                listBody
            }
            .listRowInsets(EdgeInsets(top: 0, leading: Theme.screenH, bottom: 0, trailing: Theme.screenH))
            .listRowBackground(Theme.background)
            .listRowSeparator(.hidden)
            // Paper drops the per-note chevron; the kind icon leads instead.
            .navigationLinkIndicatorVisibility(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .refreshable {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private var listBody: some View {
        if viewModel.isLoadingInitial && viewModel.notes.isEmpty {
            Text("Loading…")
                .tdCaption()
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, Theme.spacingLG)
        } else if let error = viewModel.errorMessage, viewModel.notes.isEmpty {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textPrimary)
                Button("Retry") {
                    Task { await viewModel.refresh() }
                }
                .buttonStyle(TDTextLinkStyle(color: Theme.textPrimary, size: 16))
            }
            .padding(.top, Theme.spacingLG)
        } else if viewModel.notes.isEmpty {
            Text(searchText.isEmpty ? "No notes here yet." : "No notes match.")
                .tdCaption()
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, Theme.spacingLG)
        } else {
            ForEach(Array(groupedNotes.enumerated()), id: \.offset) { index, group in
                TDSectionLabel(title: group.label)
                    // The chips keep 4pt below them, so 16 here reads as
                    // Paper's 20.
                    .padding(.top, index == 0 ? Theme.spacingMD : Theme.spacingLG)
                    .padding(.bottom, Theme.spacingXS)
                ForEach(group.notes, id: \.listRowID) { note in
                    VStack(spacing: 0) {
                        if note.listRowID != group.notes.first?.listRowID {
                            TDHairline()
                        }
                        noteRow(note)
                    }
                    // On the list row itself, so the swipe always shows.
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        swipeButtons(note)
                    }
                    .onAppear {
                        Task { await viewModel.loadMoreIfNeeded(currentItem: note) }
                    }
                }
            }

            if viewModel.isLoadingMore {
                Text("Loading…")
                    .tdCaption()
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, Theme.spacingMD)
            }
        }
    }

    /// The notes in date groups, newest first, as the list is ordered.
    /// Search results come by relevance, so they show as one group.
    private var groupedNotes: [(label: String, notes: [NotePreview])] {
        if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.notes.isEmpty ? [] : [(label: "Results", notes: viewModel.notes)]
        }
        var groups: [(label: String, notes: [NotePreview])] = []
        for note in viewModel.notes {
            let label = NoteListDates.groupLabel(for: NoteDates.parse(note.note_content_modified))
            if groups.last?.label == label {
                groups[groups.count - 1].notes.append(note)
            } else {
                groups.append((label: label, notes: [note]))
            }
        }
        return groups
    }

    private var searchField: some View {
        HStack(spacing: Theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            TextField("", text: $searchText, prompt: Text("Search \(title)").foregroundStyle(Theme.placeholder))
                .font(.system(size: 16))
                .foregroundStyle(Theme.textPrimary)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 32, height: Theme.touchMin)
                        .contentShape(Rectangle())
                }
                .buttonStyle(TDPressStyle())
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, Theme.spacingSMPlus)
        .padding(.trailing, Theme.spacingSM)
        .frame(height: Theme.touchMin)
        .background(RoundedRectangle(cornerRadius: Theme.radiusInput).fill(Theme.surface))
    }

    /// All, then each sub-category with its count, then "+ Add" (active
    /// categories only), in one row that scrolls sideways.
    private var subCategoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.spacingSM) {
                Button {
                    selectSubCategory(nil)
                } label: {
                    TDChip(title: "All", isSelected: viewModel.selectedSubCategory == nil)
                }
                ForEach(viewModel.subCategoryPills) { pill in
                    Button {
                        selectSubCategory(pill.name)
                    } label: {
                        TDChip(title: pill.name, count: pill.count, isSelected: viewModel.selectedSubCategory == pill.name)
                    }
                }
                if !categoryIsArchived {
                    Button {
                        showAddSubCategory = true
                    } label: {
                        TDAddChip()
                    }
                    .accessibilityLabel("Add sub-category")
                }
            }
            .buttonStyle(TDPressStyle())
        }
        .scrollClipDisabled()
        // With the chips' own 4pt above, 12 from the search field (Paper).
        .padding(.top, Theme.spacingSM)
    }

    private func selectSubCategory(_ name: String?) {
        viewModel.selectedSubCategory = name
        Task { await viewModel.refresh(reloadingSubCategories: false) }
    }

    // MARK: - Rows

    /// A note row. In select mode tapping picks the note; a stack row can't
    /// be picked (same as the web) and says why. Otherwise a stack opens its
    /// notes and a note opens the note.
    @ViewBuilder
    private func noteRow(_ note: NotePreview) -> some View {
        let row = NoteListRowView(
            note: note,
            showsCategory: !isCategoryFilter,
            justLanded: justLandedNoteIDs.contains(note.id)
        )
        if viewModel.isSelecting {
            let isSelected = viewModel.selectedNoteIDs.contains(note.id)
            Button {
                viewModel.toggleSelection(note)
            } label: {
                HStack(alignment: .top, spacing: Theme.spacingSMPlus) {
                    Image(systemName: note.isStack ? "circle.dashed" : (isSelected ? "checkmark.circle.fill" : "circle"))
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                        .padding(.top, Theme.spacingSMPlus)
                    VStack(alignment: .leading, spacing: 0) {
                        row
                        if note.isStack {
                            Text("Open the stack to work with its notes.")
                                .tdCaption()
                                .foregroundColor(Theme.textSecondary)
                                .padding(.bottom, Theme.spacingSMPlus)
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
                row
            }
            .buttonStyle(TDPressStyle())
        } else {
            NavigationLink {
                NoteDetailView(noteID: note.id, backTitle: title)
            } label: {
                row
            }
            .buttonStyle(TDPressStyle())
        }
    }

    /// Swipe on a row: Delete for a note; Unstack for a stack, because
    /// deleting would delete only the note that stands for it. None while
    /// selecting.
    @ViewBuilder
    private func swipeButtons(_ note: NotePreview) -> some View {
        if viewModel.isSelecting {
            EmptyView()
        } else if note.isStack, let stackId = note.stack_id {
            Button {
                Task { await viewModel.unstack(stackId: stackId) }
            } label: {
                Label("Unstack", systemImage: "square.stack.3d.up.slash")
            }
            .tint(Theme.textSecondary)
        } else {
            Button(role: .destructive) {
                noteToDelete = note
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(Theme.destructive)
        }
    }

    /// Notes this phone captured that were organized and not opened yet.
    private var justLandedNoteIDs: Set<String> {
        Set(pendingNotes.records.compactMap { record in
            record.lifecycleStatus == .organized ? record.organizedNoteId : nil
        })
    }

    // MARK: - Select mode

    /// Bottom bar in select mode. Stack needs 2 or more notes; the others 1.
    private var bulkActionBar: some View {
        let count = viewModel.selectedNotes.count
        let busy = viewModel.isPerformingBulkAction

        return HStack {
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

            Button("Delete") {
                bulkNoteCount = count
                showBulkDelete = true
            }
            .buttonStyle(TDTextLinkStyle(color: Theme.destructive, size: 16))
            .disabled(count == 0 || busy)
        }
        .buttonStyle(TDTextLinkStyle(color: Theme.textPrimary, size: 16))
        .padding(.horizontal, Theme.screenH)
        .background(Theme.background)
        .overlay(alignment: .top) { TDHairline() }
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

/// One note in a list (Paper, 03 Category): the kind of note as a small icon;
/// the title with its time or day; two lines of clean preview; then "Just
/// landed" (amber, for a note this phone captured and nobody has opened),
/// the type, and the category where the list isn't one category. Also used
/// for the notes inside a stack.
struct NoteListRowView: View {
    let note: NotePreview
    var showsCategory = true
    var justLanded = false

    var body: some View {
        HStack(alignment: .top, spacing: Theme.spacingSMPlus) {
            Image(systemName: kindSymbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 18, height: 18)
                .padding(.top, 3)
                .accessibilityLabel(kindLabel)

            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.spacingSM) {
                    Text(displayTitle())
                        .tdBody()
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let when = NoteListDates.shortLabel(for: NoteDates.parse(note.note_content_modified)) {
                        Text(when)
                            .font(.system(size: 13))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                let snippet = derivedSnippet()
                if !snippet.isEmpty {
                    Text(snippet)
                        .tdCaption()
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }

                metaLine
            }
        }
        .padding(.vertical, Theme.spacingSMPlus)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var metaLine: some View {
        let parts = metaParts
        if justLanded || !parts.isEmpty || note.stackLabel != nil {
            HStack(spacing: Theme.spacingSM) {
                if justLanded {
                    HStack(spacing: Theme.spacingXS) {
                        Circle()
                            .fill(Theme.amber)
                            .frame(width: 6, height: 6)
                        Text("Just landed")
                            .foregroundStyle(Theme.amber)
                    }
                }
                if let stackLabel = note.stackLabel {
                    Label(stackLabel, systemImage: "square.stack.3d.up")
                }
                ForEach(parts, id: \.self) { part in
                    Text(part)
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)
        }
    }

    private var metaParts: [String] {
        var parts: [String] = []
        if let type = note.note_type?.trimmingCharacters(in: .whitespacesAndNewlines), !type.isEmpty {
            parts.append(type)
        }
        if showsCategory, let category = note.category_name, !category.isEmpty {
            parts.append(category)
        }
        if let author = note.displayAuthor {
            parts.append("from \(author)")
        }
        return parts
    }

    private var kindLabel: String {
        guard let mime = note.mime_type?.lowercased() else { return "Text note" }
        if mime.hasPrefix("image") { return "Photo" }
        if mime.hasPrefix("audio") || mime.hasPrefix("voice") { return "Voice note" }
        if mime.hasPrefix("document") || mime.hasPrefix("application") { return "Document" }
        return "Text note"
    }

    private var kindSymbol: String {
        guard let mime = note.mime_type?.lowercased() else { return "text.alignleft" }
        if mime.hasPrefix("image") { return "photo" }
        if mime.hasPrefix("audio") || mime.hasPrefix("voice") { return "mic" }
        if mime.hasPrefix("document") || mime.hasPrefix("application") { return "doc" }
        return "text.alignleft"
    }

    private func displayTitle() -> String {
        if let title = note.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }

        let lines = note.preview
            .split(whereSeparator: \.isNewline)
            .map { PlainTextPreview.text(from: String($0)) }
            .filter { !$0.isEmpty }

        return lines.first ?? "Untitled"
    }

    /// The preview as clean text, without the title when it starts with it.
    private func derivedSnippet() -> String {
        let plain = PlainTextPreview.text(from: note.preview)
        guard !plain.isEmpty else { return "" }

        let title = displayTitle()
        guard title != "Untitled" else { return plain }

        if plain.hasPrefix(title) {
            return String(plain.dropFirst(title.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return plain
    }
}

#Preview {
    NavigationStack {
        NotesListView(title: "Work", filter: .category(id: 42, name: "Work"), emoji: "💼")
    }
}

import SwiftUI

// main folders screen shows sections (categories, date groups, file types). Each row displays a name and count.

struct BrowseView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var recategorizationTracker: CategoryRecategorizationTracker
    @StateObject private var viewModel = BrowseViewModel()
    @StateObject private var sessionStore = SessionStore()
    /// This phone's captures that were organized and not yet opened or
    /// dismissed: they mark their category "+1".
    @StateObject private var pendingNotes = PendingNotesViewModel()
    @State private var searchText: String = ""
    @State private var isShowingSearchResults: Bool = false
    @State private var submittedSearchText: String = ""
    @State private var showSettings = false
    @State private var showManageCategories = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Browse")
                            .tdHeadline()
                            .foregroundStyle(Theme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.bottom, Theme.spacingLG)

                        searchField

                        if isShowingInitialLoader {
                            Text("Loading…")
                                .tdCaption()
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.top, Theme.spacingLG)
                        } else {
                            folderList
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.screenH)
                    .padding(.top, Theme.spacingSM)
                    .padding(.bottom, Theme.spacingLG)
                }
                .refreshable {
                    await viewModel.loadCounts()
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .appTabBar()
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.loadCounts()
            }
            .onReceive(NotificationCenter.default.publisher(for: .categoryRecategorizationDidFinish)) { _ in
                Task { await viewModel.loadCounts() }
            }
            .onChange(of: organizedRecordIDs) { old, new in
                // A capture just landed: the server counts it now, so reload
                // so the count (or a first note's new row) matches its "+1".
                // A record only disappearing (opened or dismissed) needs none.
                if !Set(new).isSubset(of: Set(old)) {
                    Task { await viewModel.loadCounts() }
                }
            }
            .navigationDestination(isPresented: $isShowingSearchResults) {
                SearchResultsView(initialQuery: submittedSearchText)
            }
            // Categories are edited from the screen that lists them, the way
            // the folder lists in Notes and Mail work (THEDUMP-123).
            .navigationDestination(isPresented: $showManageCategories) {
                ManageCategoriesView()
            }
            .onChange(of: showManageCategories) { _, isShowing in
                if !isShowing {
                    Task { await viewModel.loadCounts() }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(appState)
                    .environmentObject(sessionStore)
            }
        }
    }

    /// Settings sits alone at the right of a 44pt bar, as on the Dump tab.
    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: Theme.touchMin, height: Theme.touchMin)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TDPressStyle())
            .accessibilityLabel("Settings")
        }
        .frame(height: 44)
        .padding(.horizontal, Theme.spacingSMPlus)
    }

    /// Typing and pressing Search opens the results screen, as before.
    private var searchField: some View {
        HStack(spacing: Theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            TextField("", text: $searchText, prompt: Text("Search all notes").foregroundStyle(Theme.placeholder))
                .font(.system(size: 16))
                .foregroundStyle(Theme.textPrimary)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .accessibilityLabel("Search all notes")
                .accessibilityAddTraits(.isSearchField)
                .onSubmit {
                    guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    submittedSearchText = searchText
                    isShowingSearchResults = true
                }
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

    private var isShowingInitialLoader: Bool {
        viewModel.isLoading
            && viewModel.categoryRows.isEmpty
            && viewModel.archivedCategoryRows.isEmpty
            && viewModel.dateGroupRows.isEmpty
            && viewModel.mimeTypeRows.isEmpty
            && viewModel.noteTypeRows.isEmpty
    }

    /// Paper's order: Recent and Routines, then categories, then types,
    /// dates, media kinds and archived categories.
    private var folderList: some View {
        VStack(alignment: .leading, spacing: 0) {
            errorSection
            recategorizingSection

            VStack(spacing: 0) {
                NavigationLink {
                    NotesListView(title: "Recent", filter: .recent(limit: 10))
                } label: {
                    BrowseRow(systemImage: "clock", title: "Recent", count: viewModel.recentCount)
                }
                // Always shown, even before the first routine, so routines
                // can be created from the phone (the web nav shows its entry
                // the same way).
                NavigationLink {
                    RoutinesListView()
                } label: {
                    BrowseRow(
                        systemImage: "repeat",
                        title: "Routines",
                        count: viewModel.routineCount,
                        unit: "routines",
                        detail: viewModel.routineOpenAskCount > 0
                            ? "\(viewModel.routineOpenAskCount) to review"
                            : nil
                    )
                }
            }
            .buttonStyle(TDPressStyle())
            .padding(.top, Theme.spacingLG)

            categorySection(title: "Categories", rows: viewModel.categoryRows, isArchived: false, showsEdit: true)
            plainSection(title: "Types", rows: viewModel.noteTypeRows, kind: .noteType) { _ in "tag" }
            plainSection(title: "Dates", rows: viewModel.dateGroupRows, kind: .dateGroup) { _ in "calendar" }
            plainSection(title: "Media kinds", rows: viewModel.mimeTypeRows, kind: .mimeType, systemImage: symbolForMediaKind)
            categorySection(title: "Archived", rows: viewModel.archivedCategoryRows, isArchived: true, showsEdit: false)
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.errorMessage {
            Label(error, systemImage: "exclamationmark.circle")
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textPrimary)
                .padding(.top, Theme.spacingLG)
        }
    }

    @ViewBuilder
    private var recategorizingSection: some View {
        if let job = recategorizationTracker.currentActiveJob {
            ReCategorizingBanner(
                categoryName: job.categoryName,
                affectedCount: job.total > 0 ? job.total : job.noteCount,
                onDismiss: nil
            )
            .padding(.top, Theme.spacingLG)
        }
    }

    /// The label sets the header's height, so Paper's 32 above and 4 below
    /// hold; Edit hangs off it on the same baseline, with its 44pt tap area.
    private func sectionHeader(_ title: String, showsEdit: Bool) -> some View {
        TDSectionLabel(title: title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: Alignment(horizontal: .trailing, vertical: .firstTextBaseline)) {
                if showsEdit {
                    Button("Edit") {
                        showManageCategories = true
                    }
                    .buttonStyle(TDTextLinkStyle(size: 13))
                    .accessibilityHint("Add, rename or archive your categories")
                }
            }
            .padding(.top, Theme.spacingXL)
            .padding(.bottom, Theme.spacingXS)
    }

    @ViewBuilder
    private func categorySection(title: String, rows: [BrowseViewModel.FolderRow], isArchived: Bool, showsEdit: Bool) -> some View {
        if !rows.isEmpty || showsEdit {
            sectionHeader(title, showsEdit: showsEdit)
            rowList(rows) { row in
                NavigationLink {
                    BrowseFolderDestinationView(
                        kind: .category,
                        name: row.name,
                        count: row.count,
                        categoryId: row.categoryId,
                        isArchivedCategory: isArchived,
                        emoji: row.emoji
                    )
                } label: {
                    BrowseRow(
                        emoji: row.emoji,
                        title: row.name,
                        count: row.count,
                        justLanded: isArchived ? 0 : justLandedCount(for: row),
                        detail: categoryStatusText(for: row)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func plainSection(
        title: String,
        rows: [BrowseViewModel.FolderRow],
        kind: BrowseFolderDestinationView.Kind,
        systemImage: @escaping (String) -> String
    ) -> some View {
        if !rows.isEmpty {
            sectionHeader(title, showsEdit: false)
            rowList(rows) { row in
                NavigationLink {
                    BrowseFolderDestinationView(kind: kind, name: row.name, count: row.count, categoryId: nil)
                } label: {
                    BrowseRow(systemImage: systemImage(row.name), title: row.name, count: row.count)
                }
            }
        }
    }

    /// Flat rows with 0.5pt hairlines between them.
    private func rowList<Row: View>(
        _ rows: [BrowseViewModel.FolderRow],
        @ViewBuilder row: @escaping (BrowseViewModel.FolderRow) -> Row
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(rows) { item in
                if item.id != rows.first?.id {
                    TDHairline()
                }
                row(item)
            }
        }
        .buttonStyle(TDPressStyle())
    }

    private func symbolForMediaKind(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.hasPrefix("image") || lower.hasPrefix("photo") { return "photo" }
        if lower.hasPrefix("audio") || lower.hasPrefix("voice") { return "mic" }
        if lower.hasPrefix("text") { return "text.alignleft" }
        if lower.hasPrefix("document") || lower.hasPrefix("application") { return "doc" }
        return "paperclip"
    }

    private func categoryStatusText(for row: BrowseViewModel.FolderRow) -> String? {
        guard let categoryId = row.categoryId else { return nil }
        return recategorizationTracker.isRecategorizing(categoryId: categoryId) ? "Re-categorizing" : nil
    }

    private var organizedRecordIDs: [String] {
        pendingNotes.records.filter { $0.lifecycleStatus == .organized }.map(\.id)
    }

    /// Notes captured on this phone that landed in this category and haven't
    /// been opened or dismissed yet. Older records have no category id, so
    /// they match by name.
    private func justLandedCount(for row: BrowseViewModel.FolderRow) -> Int {
        pendingNotes.records.filter { record in
            guard record.lifecycleStatus == .organized else { return false }
            if let id = record.categoryId { return id == row.categoryId }
            return record.categoryName?.caseInsensitiveCompare(row.name) == .orderedSame
        }.count
    }
}

struct SearchResultsView: View {
    let initialQuery: String
    @StateObject private var viewModel: NotesListViewModel
    @State private var searchText: String
    @State private var searchTask: Task<Void, Never>?

    init(initialQuery: String) {
        self.initialQuery = initialQuery
        self._searchText = State(initialValue: initialQuery)
        // Its rows open single notes, so stacks are never collapsed here,
        // even when the search box is cleared.
        let vm = NotesListViewModel(filter: .all, collapsesStacks: false)
        vm.searchQuery = initialQuery
        self._viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            Group {
                if viewModel.isLoadingInitial && viewModel.notes.isEmpty {
                    ProgressView("Searching…")
                        .foregroundColor(Theme.textPrimary)
                } else if viewModel.notes.isEmpty && !viewModel.isLoadingInitial {
                    VStack(spacing: Theme.spacingMD) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.textSecondary.opacity(0.5))
                        Text("No results found")
                            .font(.system(size: Theme.fontSizeMD))
                            .foregroundColor(Theme.textSecondary)
                    }
                } else {
                    List {
                        ForEach(viewModel.notes) { note in
                            NavigationLink {
                                NoteDetailView(noteID: note.id)
                            } label: {
                                SearchResultRowView(note: note)
                            }
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
        .navigationTitle("Search Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search all notes")
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                viewModel.searchQuery = newValue
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.refresh()
        }
    }
}

private struct SearchResultRowView: View {
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

            if let category = note.category_name, !category.isEmpty {
                Text(category)
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(Theme.textSecondary)
            }

            if let author = note.displayAuthor {
                Text("from \(author)")
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
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
}

/// One Browse row (Paper, 02 Browse): an icon or a category's emoji, the
/// name, an amber "+N" when notes from this phone just landed there, the
/// count (amber with it) and a chevron.
private struct BrowseRow: View {
    var systemImage: String?
    var emoji: String?
    let title: String
    let count: Int
    var justLanded = 0
    var detail: String?
    /// What the count counts, for VoiceOver.
    var unit = "notes"

    init(systemImage: String, title: String, count: Int, unit: String = "notes", detail: String? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.count = count
        self.unit = unit
        self.detail = detail
    }

    init(emoji: String?, title: String, count: Int, justLanded: Int, detail: String?) {
        self.emoji = emoji
        self.title = title
        self.count = count
        self.justLanded = justLanded
        self.detail = detail
    }

    var body: some View {
        HStack(spacing: Theme.spacingSMPlus) {
            HStack(spacing: systemImage == nil ? 6 : Theme.spacingSMPlus) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 18, height: 18)
                        .accessibilityHidden(true)
                } else {
                    // A fixed width, so names line up whether a category
                    // has an emoji or the folder stand-in.
                    CategoryGlyph(emoji: emoji, size: 16)
                        .frame(width: 20)
                }
                Text(title)
                    .tdBody()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if let detail {
                    Text(detail)
                        .tdCaption()
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if justLanded > 0 {
                Text("+\(justLanded)")
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(Theme.amber)
                    .accessibilityHidden(true)
            }
            Text("\(count)")
                .font(.system(size: 16))
                .monospacedDigit()
                .foregroundStyle(justLanded > 0 ? Theme.amber : Theme.textSecondary)
                .accessibilityHidden(true)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 48)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(justLanded > 0 ? "\(count) \(unit), \(justLanded) just landed" : "\(count) \(unit)")
    }
}

#Preview {
    BrowseView()
        .environmentObject(AppState())
        .environmentObject(CategoryRecategorizationTracker.shared)
}

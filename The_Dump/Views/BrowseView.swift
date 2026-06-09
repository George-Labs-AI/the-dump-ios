import SwiftUI

// main folders screen shows sections (categories, date groups, file types). Each row displays a name and count.

struct BrowseView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var recategorizationTracker: CategoryRecategorizationTracker
    @StateObject private var viewModel = BrowseViewModel()
    @StateObject private var sessionStore = SessionStore()
    @State private var searchText: String = ""
    @State private var isShowingSearchResults: Bool = false
    @State private var submittedSearchText: String = ""
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                Group {
                    if isShowingInitialLoader {
                        ProgressView("Loading…")
                            .foregroundColor(Theme.textPrimary)
                    } else {
                        folderList
                        .scrollContentBackground(.hidden)
                        .listStyle(.insetGrouped)
                        .refreshable {
                            await viewModel.loadCounts()
                        }
                    }
                }
            }
            .navigationTitle("Folders")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                await viewModel.loadCounts()
            }
            .onReceive(NotificationCenter.default.publisher(for: .categoryRecategorizationDidFinish)) { _ in
                Task { await viewModel.loadCounts() }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search all notes")
            .onSubmit(of: .search) {
                guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                submittedSearchText = searchText
                isShowingSearchResults = true
            }
            .navigationDestination(isPresented: $isShowingSearchResults) {
                SearchResultsView(initialQuery: submittedSearchText)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: Theme.fontSizeLG))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(appState)
                    .environmentObject(sessionStore)
            }
        }
    }

    private var isShowingInitialLoader: Bool {
        viewModel.isLoading
            && viewModel.categoryRows.isEmpty
            && viewModel.archivedCategoryRows.isEmpty
            && viewModel.dateGroupRows.isEmpty
            && viewModel.mimeTypeRows.isEmpty
    }

    private var folderList: some View {
        List {
            errorSection
            recategorizingSection
            recentSection
            activeCategoriesSection
            dateGroupSection
            mimeTypeSection
            archivedCategoriesSection
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.errorMessage {
            Section {
                Text(error)
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.accent)
            }
            .listRowBackground(Theme.surface)
        }
    }

    @ViewBuilder
    private var recategorizingSection: some View {
        if let job = recategorizationTracker.currentActiveJob {
            Section {
                ReCategorizingBanner(
                    categoryName: job.categoryName,
                    affectedCount: job.total > 0 ? job.total : job.noteCount,
                    onDismiss: nil
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: Theme.spacingSM, leading: Theme.spacingMD, bottom: Theme.spacingSM, trailing: Theme.spacingMD))
            }
        }
    }

    private var recentSection: some View {
        Section {
            NavigationLink {
                NotesListView(title: "Recent", filter: .recent(limit: 10))
            } label: {
                BrowseFolderRowView(icon: "🕐", title: "Recent", count: viewModel.recentCount)
            }
            .listRowBackground(Theme.surface)
        } header: {
            Text("Recent")
                .sectionLabel()
                .foregroundColor(Theme.textSecondary)
        }
    }

    @ViewBuilder
    private var activeCategoriesSection: some View {
        if !viewModel.categoryRows.isEmpty {
            Section {
                ForEach(viewModel.categoryRows) { row in
                    categoryNavigationLink(row: row, icon: "📁", isArchived: false)
                }
            } header: {
                Text("Active Categories")
                    .sectionLabel()
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    private var dateGroupSection: some View {
        Section {
            ForEach(viewModel.dateGroupRows) { row in
                NavigationLink {
                    BrowseFolderDestinationView(kind: .dateGroup, name: row.name, count: row.count, categoryId: nil)
                } label: {
                    BrowseFolderRowView(icon: "📅", title: row.name, count: row.count)
                }
                .listRowBackground(Theme.surface)
            }
        } header: {
            Text("Date Groups")
                .sectionLabel()
                .foregroundColor(Theme.textSecondary)
        }
    }

    private var mimeTypeSection: some View {
        Section {
            ForEach(viewModel.mimeTypeRows) { row in
                NavigationLink {
                    BrowseFolderDestinationView(kind: .mimeType, name: row.name, count: row.count, categoryId: nil)
                } label: {
                    BrowseFolderRowView(icon: emojiForMimeType(row.name), title: row.name, count: row.count)
                }
                .listRowBackground(Theme.surface)
            }
        } header: {
            Text("File Types")
                .sectionLabel()
                .foregroundColor(Theme.textSecondary)
        }
    }

    @ViewBuilder
    private var archivedCategoriesSection: some View {
        if !viewModel.archivedCategoryRows.isEmpty {
            Section {
                ForEach(viewModel.archivedCategoryRows) { row in
                    categoryNavigationLink(row: row, icon: "🗄️", isArchived: true)
                }
            } header: {
                Text("Archived Categories")
                    .sectionLabel()
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    private func categoryNavigationLink(row: BrowseViewModel.FolderRow, icon: String, isArchived: Bool) -> some View {
        NavigationLink {
            BrowseFolderDestinationView(
                kind: .category,
                name: row.name,
                count: row.count,
                categoryId: row.categoryId,
                isArchivedCategory: isArchived
            )
        } label: {
            BrowseFolderRowView(
                icon: icon,
                title: row.name,
                count: row.count,
                statusText: categoryStatusText(for: row)
            )
        }
        .listRowBackground(Theme.surface)
    }

    private func emojiForMimeType(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.hasPrefix("image") { return "📷" }
        if lower.hasPrefix("audio") || lower.hasPrefix("voice") { return "🎤" }
        if lower.hasPrefix("text") { return "✏️" }
        if lower.hasPrefix("document") || lower.hasPrefix("application") { return "📤" }
        return "📎"
    }

    private func categoryStatusText(for row: BrowseViewModel.FolderRow) -> String? {
        guard let categoryId = row.categoryId else { return nil }
        return recategorizationTracker.isRecategorizing(categoryId: categoryId) ? "Re-categorizing" : nil
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
        let vm = NotesListViewModel(filter: .all)
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

private struct BrowseFolderRowView: View {
    let icon: String
    let title: String
    let count: Int
    let statusText: String?

    init(icon: String, title: String, count: Int, statusText: String? = nil) {
        self.icon = icon
        self.title = title
        self.count = count
        self.statusText = statusText
    }

    var body: some View {
        HStack(spacing: Theme.spacingSMPlus) {
            Text(icon)
                .font(.system(size: 18))
                .frame(width: 32, height: 32)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusCatIcon))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.spacingXS) {
                    Text(title)
                        .font(.system(size: Theme.fontSizeMD, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    if let statusText {
                        Text(statusText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.warning)
                            .padding(.horizontal, Theme.spacingSM)
                            .padding(.vertical, 3)
                            .background(Theme.warning.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            Text("\(count)")
                .font(.system(size: Theme.fontSizeSM, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, Theme.spacingXS)
    }
}

#Preview {
    BrowseView()
        .environmentObject(AppState())
        .environmentObject(CategoryRecategorizationTracker.shared)
}

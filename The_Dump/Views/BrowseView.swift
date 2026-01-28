import SwiftUI

//main folders screen shows sections (categories, date groups, file types). Each row displays a name and count. 

struct BrowseView: View {
    @StateObject private var viewModel = BrowseViewModel()
    @State private var searchText: String = ""
    @State private var isShowingSearchResults: Bool = false
    @State private var submittedSearchText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                Group {
                    if viewModel.isLoading && viewModel.categoryRows.isEmpty && viewModel.dateGroupRows.isEmpty && viewModel.mimeTypeRows.isEmpty {
                        ProgressView("Loading…")
                            .foregroundColor(Theme.textPrimary)
                    } else {
                        List {
                            if let error = viewModel.errorMessage {
                                Section {
                                    Text(error)
                                        .font(.system(size: Theme.fontSizeSM))
                                        .foregroundColor(Theme.accent)
                                }
                                .listRowBackground(Theme.darkGray)
                            }

                            Section {
                                NavigationLink {
                                    NotesListView(title: "Recent", filter: .recent(limit: 10))
                                } label: {
                                    BrowseFolderRowView(title: "Recent", count: 10)
                                }
                                .listRowBackground(Theme.darkGray)
                            } header: {
                                Text("Recent")
                                    .foregroundColor(Theme.textSecondary)
                            }

                            Section {
                                ForEach(viewModel.categoryRows) { row in
                                    NavigationLink {
                                        BrowseFolderDestinationView(kind: .category, name: row.name, count: row.count)
                                    } label: {
                                        BrowseFolderRowView(title: row.name, count: row.count)
                                    }
                                    .listRowBackground(Theme.darkGray)
                                }
                            } header: {
                                Text("Categories")
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Section {
                                ForEach(viewModel.dateGroupRows) { row in
                                    NavigationLink {
                                        BrowseFolderDestinationView(kind: .dateGroup, name: row.name, count: row.count)
                                    } label: {
                                        BrowseFolderRowView(title: row.name, count: row.count)
                                    }
                                    .listRowBackground(Theme.darkGray)
                                }
                            } header: {
                                Text("Date Groups")
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Section {
                                ForEach(viewModel.mimeTypeRows) { row in
                                    NavigationLink {
                                        BrowseFolderDestinationView(kind: .mimeType, name: row.name, count: row.count)
                                    } label: {
                                        BrowseFolderRowView(title: row.name, count: row.count)
                                    }
                                    .listRowBackground(Theme.darkGray)
                                }
                            } header: {
                                Text("File Types")
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
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
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search all notes")
            .onSubmit(of: .search) {
                guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                submittedSearchText = searchText
                isShowingSearchResults = true
            }
            .navigationDestination(isPresented: $isShowingSearchResults) {
                SearchResultsView(initialQuery: submittedSearchText)
            }
        }
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
            Text(note.preview.components(separatedBy: .newlines).first ?? "Untitled")
                .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)

            Text(note.preview)
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(2)

            if let category = note.category_name, !category.isEmpty {
                Text(category)
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct BrowseFolderRowView: View {
    let title: String
    let count: Int
    
    var body: some View {
        HStack(spacing: Theme.spacingMD) {
            Text(title)
                .font(.system(size: Theme.fontSizeMD, weight: .medium))
                .foregroundColor(Theme.textPrimary)
            
            Spacer()
            
            Text("\(count)")
                .font(.system(size: Theme.fontSizeSM, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BrowseView()
}




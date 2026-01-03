import SwiftUI

struct NotesListView: View {
    private let title: String
    @StateObject private var viewModel: NotesListViewModel
    @State private var searchText: String = ""
    @State private var searchTask: Task<Void, Never>?

    init(title: String, filter: NotesListViewModel.Filter) {
        self.title = title
        _viewModel = StateObject(wrappedValue: NotesListViewModel(filter: filter))
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
    }
}

private struct NoteListRowView: View {
    let note: NotePreview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(derivedTitle(from: note.preview))
                .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
            
            let snippet = derivedSnippet(from: note.preview)
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
    
    private func derivedTitle(from preview: String) -> String {
        let lines = preview
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return lines.first ?? "Untitled"
    }
    
    private func derivedSnippet(from preview: String) -> String {
        let trimmed = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        let title = derivedTitle(from: trimmed)
        // If we couldn't derive a meaningful title, don't try to remove anything.
        guard title != "Untitled" else { return trimmed }
        
        // Remove the title only if it is actually a prefix of the preview.
        if trimmed.hasPrefix(title) {
            let remainder = trimmed.dropFirst(title.count)
            return remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Safety fallback: avoid deleting content if title derivation doesn't match the prefix.
            return trimmed
        }
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



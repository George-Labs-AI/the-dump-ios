import Foundation
import Combine

@MainActor
final class NotesListViewModel: ObservableObject {
    enum Filter: Equatable {
        case all
        case category(name: String)
        case mimeType(String)
        case dateGroup(name: String, startTime: String, endTime: String)
        case recent(limit: Int)
    }

    @Published private(set) var notes: [NotePreview] = []
    @Published private(set) var isLoadingInitial: Bool = false
    @Published private(set) var isLoadingMore: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasMore: Bool = false
    @Published var searchQuery: String = ""
    @Published var selectedSubCategory: String?
    @Published private(set) var availableSubCategories: [String] = []

    private let filter: Filter
    private var nextCursorTime: String?
    private var nextCursorId: String?

    /// Returns the category name if this filter is a category filter
    var categoryName: String? {
        if case .category(let name) = filter {
            return name
        }
        return nil
    }

    init(filter: Filter) {
        self.filter = filter
    }

    /// Load available subcategories from the notes in the current category.
    /// Skips rebuilding when a sub-category filter is active, because the
    /// filtered results only contain that one sub-category and would wipe the list.
    func loadSubCategories() async {
        guard case .category = filter else { return }
        guard selectedSubCategory == nil else { return }

        // Collect unique subcategories from all loaded notes
        var subCats = Set<String>()
        for note in notes {
            if let names = note.sub_cat_names {
                for name in names where !name.isEmpty {
                    subCats.insert(name)
                }
            }
        }

        availableSubCategories = subCats.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Add a new subcategory to the available list (called after creating one)
    func addSubCategoryToList(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !availableSubCategories.contains(where: { $0.lowercased() == trimmed }) else { return }
        availableSubCategories.append(name)
        availableSubCategories.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Clear the subcategory filter
    func clearSubCategoryFilter() {
        selectedSubCategory = nil
    }
    
    func refresh() async {
        guard !isLoadingInitial else { return }
        isLoadingInitial = true
        isLoadingMore = false
        errorMessage = nil
        nextCursorTime = nil
        nextCursorId = nil
        
        do {
            let response = try await fetch(limit: 30, cursorTime: nil, cursorId: nil)
            notes = response.notes
            nextCursorTime = response.next_cursor_time
            nextCursorId = response.next_cursor_id
            hasMore = response.has_more
            await loadSubCategories()
        } catch {
            errorMessage = error.localizedDescription
            notes = []
            hasMore = false
        }

        isLoadingInitial = false
    }
    
    func loadMoreIfNeeded(currentItem: NotePreview?) async {
        guard let currentItem else { return }
        guard hasMore else { return }
        guard !isLoadingInitial else { return }
        guard !isLoadingMore else { return }

        // Recent filter shows a fixed number of notes, no pagination
        if case .recent = filter { return }
        
        // Trigger pagination when the user reaches the end of the current list.
        let isLast = notes.last?.id == currentItem.id
        guard isLast else { return }
        
        isLoadingMore = true
        errorMessage = nil
        
        do {
            let response = try await fetch(limit: 30, cursorTime: nextCursorTime, cursorId: nextCursorId)
            notes.append(contentsOf: response.notes)
            nextCursorTime = response.next_cursor_time
            nextCursorId = response.next_cursor_id
            hasMore = response.has_more
            await loadSubCategories()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }
    
    private func fetch(limit: Int, cursorTime: String?, cursorId: String?) async throws -> NoteListResponse {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let q: String? = query.isEmpty ? nil : query

        switch filter {
        case .all:
            return try await NotesService.shared.fetchNotes(
                limit: limit,
                cursorTime: cursorTime,
                cursorId: cursorId,
                q: q
            )
        case .category(let name):
            return try await NotesService.shared.fetchNotes(
                limit: limit,
                cursorTime: cursorTime,
                cursorId: cursorId,
                categoryName: name,
                subCatName: selectedSubCategory,
                q: q
            )
        case .mimeType(let mime):
            return try await NotesService.shared.fetchNotes(
                limit: limit,
                cursorTime: cursorTime,
                cursorId: cursorId,
                mimeGroup: mime,
                q: q
            )
        case .dateGroup(_, let startTime, let endTime):
            let start = startTime.trimmingCharacters(in: .whitespacesAndNewlines)
            let end = endTime.trimmingCharacters(in: .whitespacesAndNewlines)

            // "All Time" (or unknown): omit date parameters entirely.
            guard !start.isEmpty, !end.isEmpty else {
                return try await NotesService.shared.fetchNotes(
                    limit: limit,
                    cursorTime: cursorTime,
                    cursorId: cursorId,
                    q: q
                )
            }

            return try await NotesService.shared.fetchNotes(
                limit: limit,
                cursorTime: cursorTime,
                cursorId: cursorId,
                startTime: start,
                endTime: end,
                tz: TimeZone.current.identifier,
                q: q
            )
        case .recent(let recentLimit):
            // For recent, we only fetch the specified limit (pagination disabled in loadMoreIfNeeded)
            return try await NotesService.shared.fetchNotes(
                limit: recentLimit,
                cursorTime: nil,
                cursorId: nil,
                q: q
            )
        }
    }
}

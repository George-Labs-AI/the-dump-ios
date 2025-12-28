import Foundation
import Combine

@MainActor
final class NotesListViewModel: ObservableObject {
    enum Filter: Equatable {
        case category(name: String)
        case mimeType(String)
        case dateGroup(name: String, startTime: String, endTime: String)
    }
    
    @Published private(set) var notes: [NotePreview] = []
    @Published private(set) var isLoadingInitial: Bool = false
    @Published private(set) var isLoadingMore: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasMore: Bool = false
    
    private let filter: Filter
    private var nextCursorTime: String?
    private var nextCursorId: String?
    
    init(filter: Filter) {
        self.filter = filter
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
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoadingMore = false
    }
    
    private func fetch(limit: Int, cursorTime: String?, cursorId: String?) async throws -> NoteListResponse {
        switch filter {
        case .category(let name):
            return try await NotesService.shared.fetchNotes(
                limit: limit,
                cursorTime: cursorTime,
                cursorId: cursorId,
                categoryName: name
            )
        case .mimeType(let mime):
            return try await NotesService.shared.fetchNotes(
                limit: limit,
                cursorTime: cursorTime,
                cursorId: cursorId,
                mimeGroup: mime
            )
        case .dateGroup(_, let startTime, let endTime):
            let start = startTime.trimmingCharacters(in: .whitespacesAndNewlines)
            let end = endTime.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // "All Time" (or unknown): omit date parameters entirely.
            guard !start.isEmpty, !end.isEmpty else {
                return try await NotesService.shared.fetchNotes(
                    limit: limit,
                    cursorTime: cursorTime,
                    cursorId: cursorId
                )
            }
            
            return try await NotesService.shared.fetchNotes(
                limit: limit,
                cursorTime: cursorTime,
                cursorId: cursorId,
                startTime: start,
                endTime: end,
                tz: TimeZone.current.identifier
            )
        }
    }
}



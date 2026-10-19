import Foundation
import Combine

@MainActor
final class NotesListViewModel: ObservableObject {
    enum Filter: Equatable {
        case all
        case category(id: Int, name: String)
        case mimeType(String)
        case dateGroup(name: String, startTime: String, endTime: String)
        case recent(limit: Int)
        case noteType(String)
    }

    @Published private(set) var notes: [NotePreview] = []
    @Published private(set) var isLoadingInitial: Bool = false
    @Published private(set) var isLoadingMore: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasMore: Bool = false
    @Published var searchQuery: String = ""
    @Published var selectedSubCategory: String?
    @Published private(set) var subCategoryPills: [SubCategoryPill] = []

    /// Select mode: the notes picked for Stack, Delete, Change category or
    /// Change type. Rows that stand for a whole stack can't be picked (same
    /// rule as the web), because acting on them would reach only one note.
    @Published var isSelecting: Bool = false
    @Published var selectedNoteIDs: Set<String> = []
    @Published private(set) var isPerformingBulkAction: Bool = false

    private let filter: Filter
    private var nextCursorTime: String?
    private var nextCursorId: String?
    private var nextOffset: Int = 0

    // Inputs to the sub-category pills (see SubCategoryPills.build).
    private var categoryMap: CategoryMapResponse?
    private var subCategoryCounts: [String: Int]?
    private var subCategoryNamesOnNotes: Set<String> = []
    private var addedSubCategories: [String] = []

    /// Returns the category display name if this filter is a category filter.
    var categoryName: String? {
        if case .category(_, let name) = filter {
            return name
        }
        return nil
    }

    var categoryId: Int? {
        if case .category(let id, _) = filter {
            return id
        }
        return nil
    }

    init(filter: Filter) {
        self.filter = filter
    }

    /// Ask the server for this category's sub-categories (the category map)
    /// and their note counts. Either can fail on its own; the pills then fall
    /// back to what the loaded notes show, so a failure never hides the notes.
    private func loadSubCategoryData() async {
        async let mapTask = NotesService.shared.fetchCategoryMap()
        async let countsTask = NotesService.shared.fetchCounts()
        categoryMap = try? await mapTask
        subCategoryCounts = (try? await countsTask)?.subCategoryCounts
    }

    /// Rebuild the pills from the category map, the counts and the names on
    /// the loaded notes.
    private func rebuildSubCategoryPills() {
        guard let categoryName else { return }
        subCategoryPills = SubCategoryPills.build(
            categoryName: categoryName,
            map: categoryMap,
            counts: subCategoryCounts,
            namesOnNotes: subCategoryNamesOnNotes.sorted(),
            added: addedSubCategories
        )
    }

    /// Remember the sub-category names on newly loaded notes. A filtered list
    /// only holds one sub-category, so it adds to what an unfiltered load saw
    /// instead of replacing it.
    private func collectSubCategoryNames(from loaded: [NotePreview], replacing: Bool) {
        let names = loaded.flatMap { $0.sub_cat_names ?? [] }.filter { !$0.isEmpty }
        if replacing {
            subCategoryNamesOnNotes = Set(names)
        } else {
            subCategoryNamesOnNotes.formUnion(names)
        }
    }

    /// Add a new subcategory to the available list (called after creating one)
    func addSubCategoryToList(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        addedSubCategories.append(trimmed)
        rebuildSubCategoryPills()
    }

    /// Clear the subcategory filter
    func clearSubCategoryFilter() {
        selectedSubCategory = nil
    }
    
    /// Reload the first page. `reloadingSubCategories` also asks the server
    /// for the category's sub-categories and counts again; tapping a pill or
    /// typing a search doesn't need that.
    func refresh(reloadingSubCategories: Bool = true) async {
        guard !isLoadingInitial else { return }
        isLoadingInitial = true
        isLoadingMore = false
        errorMessage = nil
        nextCursorTime = nil
        nextCursorId = nil
        nextOffset = 0

        if reloadingSubCategories, categoryName != nil {
            async let subCategoryData: Void = loadSubCategoryData()
            await loadFirstPage()
            await subCategoryData
        } else {
            await loadFirstPage()
        }
        rebuildSubCategoryPills()

        // Drop picks that are no longer on screen (deleted, moved, stacked).
        let visible = Set(notes.map(\.id))
        selectedNoteIDs.formIntersection(visible)

        isLoadingInitial = false
    }

    private func loadFirstPage() async {
        do {
            let response = try await fetch(limit: 30, cursorTime: nil, cursorId: nil, offset: 0)
            notes = response.notes
            nextCursorTime = response.next_cursor_time
            nextCursorId = response.next_cursor_id
            // Fall back to the count we received so we always advance, even if the
            // server claims has_more without returning next_offset.
            nextOffset = response.next_offset ?? response.notes.count
            hasMore = response.has_more
            collectSubCategoryNames(from: response.notes, replacing: selectedSubCategory == nil)
        } catch {
            errorMessage = error.localizedDescription
            notes = []
            hasMore = false
        }
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
            let response = try await fetch(
                limit: 30,
                cursorTime: nextCursorTime,
                cursorId: nextCursorId,
                offset: nextOffset
            )
            notes.append(contentsOf: response.notes)
            nextCursorTime = response.next_cursor_time
            nextCursorId = response.next_cursor_id
            // Always advance nextOffset. If the server returns has_more without
            // a next_offset, fall back to the count we received so we never
            // re-request the same page and loop forever.
            nextOffset = response.next_offset ?? (nextOffset + response.notes.count)
            hasMore = response.has_more
            collectSubCategoryNames(from: response.notes, replacing: false)
            rebuildSubCategoryPills()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }
    
    func deleteNote(noteId: String) async -> Bool {
        errorMessage = nil

        do {
            try await NotesService.shared.deleteNote(noteId: noteId)
            notes.removeAll { $0.id == noteId }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Select mode

    func startSelecting() {
        selectedNoteIDs = []
        isSelecting = true
    }

    func stopSelecting() {
        isSelecting = false
        selectedNoteIDs = []
    }

    func toggleSelection(_ note: NotePreview) {
        guard isSelecting, !note.isStack else { return }
        if selectedNoteIDs.contains(note.id) {
            selectedNoteIDs.remove(note.id)
        } else {
            selectedNoteIDs.insert(note.id)
        }
    }

    /// Picks in list order, leaving out any stack row (List selection can't
    /// pick one, but this keeps the requests safe regardless).
    var selectedNotes: [NotePreview] {
        notes.filter { selectedNoteIDs.contains($0.id) && !$0.isStack }
    }

    var canStackSelection: Bool { selectedNotes.count >= 2 }

    /// Bundle the selected notes into a new stack.
    func stackSelected() async -> Bool {
        let ids = selectedNotes.map(\.id)
        guard ids.count >= 2 else { return false }
        return await performBulkAction {
            _ = try await NotesService.shared.stackNotes(noteIds: ids)
        }
    }

    /// Delete the selected notes. The view asks for the typed count first
    /// (BulkDeleteConfirmation).
    func deleteSelected() async -> Bool {
        let ids = selectedNotes.map(\.id)
        guard !ids.isEmpty else { return false }
        return await performBulkAction {
            _ = try await NotesService.shared.bulkDeleteNotes(noteIds: ids)
        }
    }

    /// Move the selected notes into `category`, which must be one of the
    /// user's active categories (the server refuses any other name). Sends the
    /// category's own spelling, which the server stores as the note's
    /// category name.
    func moveSelected(toCategory category: CategoryResponse) async -> Bool {
        let ids = selectedNotes.map(\.id)
        let name = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ids.isEmpty, !name.isEmpty else { return false }
        return await performBulkAction {
            _ = try await NotesService.shared.bulkUpdateNotes(
                BulkUpdateNotesRequest(noteIds: ids, category: name)
            )
        }
    }

    /// Give the selected notes `type`, one of NoteTypeCatalog's types.
    func changeTypeOfSelected(to type: String) async -> Bool {
        let ids = selectedNotes.map(\.id)
        let cleaned = type.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ids.isEmpty, !cleaned.isEmpty else { return false }
        return await performBulkAction {
            _ = try await NotesService.shared.bulkUpdateNotes(
                BulkUpdateNotesRequest(noteIds: ids, type: cleaned)
            )
        }
    }

    /// Dissolve a stack shown in this list; its notes come back as ordinary rows.
    func unstack(stackId: String) async -> Bool {
        await performBulkAction {
            try await NotesService.shared.unstackNotes(stackId: stackId)
        }
    }

    /// Runs one stack or bulk request, then leaves select mode and reloads
    /// the list. On failure the selection stays so the user can try again.
    private func performBulkAction(_ action: () async throws -> Void) async -> Bool {
        guard !isPerformingBulkAction else { return false }
        isPerformingBulkAction = true
        errorMessage = nil
        defer { isPerformingBulkAction = false }

        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
            return false
        }

        stopSelecting()
        await refresh()
        return true
    }

    private func fetch(limit: Int, cursorTime: String?, cursorId: String?, offset: Int) async throws -> NoteListResponse {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let q: String? = query.isEmpty ? nil : query

        // Enforce: search mode uses offset only; browse mode uses cursor only.
        let ct: String? = q == nil ? cursorTime : nil
        let ci: String? = q == nil ? cursorId   : nil
        let off: Int?   = q == nil ? nil        : offset
        // Browse mode shows each stack as one row; search results always
        // list notes one by one (the server ignores stacks=1 with q anyway).
        let stacks = q == nil

        switch filter {
        case .all:
            return try await NotesService.shared.fetchNotes(
                limit: limit,
                cursorTime: ct,
                cursorId: ci,
                q: q,
                offset: off,
                stacks: stacks
            )
        case .category(let id, _):
            return try await NotesService.shared.fetchNotes(
                limit: limit,
                cursorTime: ct,
                cursorId: ci,
                categoryId: id,
                subCatName: selectedSubCategory,
                q: q,
                offset: off,
                stacks: stacks
            )
        case .mimeType(let mime):
            return try await NotesService.shared.fetchNotes(
                limit: limit,
                cursorTime: ct,
                cursorId: ci,
                mimeGroup: mime,
                q: q,
                offset: off,
                stacks: stacks
            )
        case .dateGroup(_, let startTime, let endTime):
            let start = startTime.trimmingCharacters(in: .whitespacesAndNewlines)
            let end = endTime.trimmingCharacters(in: .whitespacesAndNewlines)

            // "All Time" (or unknown): omit date parameters entirely.
            guard !start.isEmpty, !end.isEmpty else {
                return try await NotesService.shared.fetchNotes(
                    limit: limit,
                    cursorTime: ct,
                    cursorId: ci,
                    q: q,
                    offset: off,
                    stacks: stacks
                )
            }

            return try await NotesService.shared.fetchNotes(
                limit: limit,
                cursorTime: ct,
                cursorId: ci,
                startTime: start,
                endTime: end,
                tz: TimeZone.current.identifier,
                q: q,
                offset: off,
                stacks: stacks
            )
        case .recent(let recentLimit):
            // For recent, we only fetch the specified limit (pagination disabled in loadMoreIfNeeded)
            return try await NotesService.shared.fetchNotes(
                limit: recentLimit,
                cursorTime: nil,
                cursorId: nil,
                q: q,
                offset: off,
                stacks: stacks
            )
        case .noteType(let type):
            return try await NotesService.shared.fetchNotes(
                limit: limit,
                cursorTime: ct,
                cursorId: ci,
                q: q,
                noteType: type,
                offset: off,
                stacks: stacks
            )
        }
    }
}

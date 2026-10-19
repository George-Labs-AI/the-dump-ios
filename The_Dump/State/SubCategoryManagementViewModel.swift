import Foundation
import Combine

extension Notification.Name {
    /// Posted after a sub-category is renamed, edited, deleted or restored
    /// in Settings. userInfo["categoryId"] is its category's ID and
    /// userInfo["change"] a `SubCategoryChange`, so screens holding
    /// sub-category names can reload them.
    static let subCategoriesDidChange = Notification.Name("subCategoriesDidChange")
}

/// What happened to a sub-category, for screens that show its name.
enum SubCategoryChange: Equatable {
    case renamed(from: String, to: String)
    /// Description or keywords only; the name is unchanged.
    case edited(name: String)
    case archived(name: String)
    case restored(name: String)

    static let categoryIdKey = "categoryId"
    static let changeKey = "change"

    func post(categoryId: Int, to center: NotificationCenter = .default) {
        center.post(
            name: .subCategoriesDidChange,
            object: nil,
            userInfo: [Self.categoryIdKey: categoryId, Self.changeKey: self]
        )
    }

    /// The category and change a `.subCategoriesDidChange` notification
    /// carries, or nil for anything else.
    static func from(_ notification: Notification) -> (categoryId: Int, change: SubCategoryChange)? {
        guard notification.name == .subCategoriesDidChange,
              let categoryId = notification.userInfo?[categoryIdKey] as? Int,
              let change = notification.userInfo?[changeKey] as? SubCategoryChange else { return nil }
        return (categoryId, change)
    }

    /// The sub-category filter to keep after this change: a renamed one
    /// follows its new name, a deleted one is cleared, and any other filter
    /// stays. Names are matched ignoring case and surrounding spaces.
    func selection(after current: String?) -> String? {
        guard let current else { return nil }
        let key = CategoryMapResponse.key(current)
        switch self {
        case .renamed(let from, let to):
            return CategoryMapResponse.key(from) == key ? to : current
        case .archived(let name):
            return CategoryMapResponse.key(name) == key ? nil : current
        case .edited, .restored:
            return current
        }
    }
}

/// The server calls behind the sub-category screens, as closures so tests
/// can stand in for the server.
struct SubCategoryClient {
    var list: (_ categoryId: Int) async throws -> [SubCategoryItem]
    var update: (_ subCatId: Int, _ update: SubCategoryUpdateRequest) async throws -> UpdateSubCategoryResponse
    var archive: (_ subCatId: Int) async throws -> ArchiveSubCategoryResponse
    var restore: (_ subCatId: Int) async throws -> RestoreSubCategoryResponse

    static let live = SubCategoryClient(
        list: { try await NotesService.shared.fetchSubCategories(categoryId: $0) },
        update: { try await NotesService.shared.updateSubCategory(id: $0, update: $1) },
        archive: { try await NotesService.shared.archiveSubCategory(id: $0) },
        restore: { try await NotesService.shared.restoreSubCategory(id: $0) }
    )

#if DEBUG
    /// Sample sub-categories for SwiftUI previews; changes go nowhere.
    static let preview: SubCategoryClient = {
        let items = [
            SubCategoryItem(subCatId: 1, categoryId: 1, name: "grocery lists", description: "Weekly shops",
                            keywords: ["milk", "eggs"], noteCount: 7,
                            routines: [SubCategoryRoutine(slug: "meal-plan", name: "Meal plan")]),
            SubCategoryItem(subCatId: 2, categoryId: 1, name: "receipts", noteCount: 1),
            SubCategoryItem(subCatId: 3, categoryId: 1, name: "old trips", archived: true)
        ]
        return SubCategoryClient(
            list: { _ in items },
            update: { id, _ in UpdateSubCategoryResponse(subcategory: items.first { $0.subCatId == id }) },
            archive: { _ in ArchiveSubCategoryResponse() },
            restore: { id in RestoreSubCategoryResponse(subcategory: items.first { $0.subCatId == id }) }
        )
    }()
#endif
}

/// One category's sub-categories in Settings: the active ones with their
/// note counts, the archived ones, and editing, deleting (archiving) and
/// restoring them. Every change is announced with `.subCategoriesDidChange`
/// so filter pills and note screens stop showing old names.
@MainActor
final class SubCategoryManagementViewModel: ObservableObject {
    enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
        /// The server doesn't offer these routes (it answered "not found"),
        /// so the section stays hidden rather than showing an error.
        case unavailable
    }

    @Published private(set) var active: [SubCategoryItem] = []
    @Published private(set) var archived: [SubCategoryItem] = []
    @Published private(set) var loadState: LoadState = .loading
    /// Sub-categories with a save, delete or restore under way.
    @Published private(set) var busyIDs: Set<Int> = []

    let categoryId: Int
    private let client: SubCategoryClient
    private let notificationCenter: NotificationCenter
    private let onChange: () -> Void

    init(
        categoryId: Int,
        client: SubCategoryClient? = nil,
        notificationCenter: NotificationCenter = .default,
        onChange: @escaping () -> Void = {}
    ) {
        self.categoryId = categoryId
        self.client = client ?? .live
        self.notificationCenter = notificationCenter
        self.onChange = onChange
    }

    /// Active and archived together, for checking a new name against both.
    var all: [SubCategoryItem] { active + archived }

    func item(withID id: Int) -> SubCategoryItem? {
        all.first { $0.subCatId == id }
    }

    func isBusy(_ item: SubCategoryItem) -> Bool {
        busyIDs.contains(item.subCatId)
    }

    func load() async {
        if active.isEmpty && archived.isEmpty {
            loadState = .loading
        }
        do {
            let items = try await client.list(categoryId)
            show(items)
            loadState = .loaded
        } catch APIError.notFound(_) {
            loadState = .unavailable
        } catch {
            // Keep what is on screen; say why the reload failed only when
            // there is nothing to show.
            if active.isEmpty && archived.isEmpty {
                loadState = .failed(SubCategoryWording.loadFailed)
            }
        }
    }

    /// Save the draft's changes. Returns nil on success, or the message to
    /// show.
    func save(_ draft: SubCategoryEditDraft) async -> String? {
        let original = draft.original
        if let clash = draft.nameClash(among: all) {
            return clash
        }
        let update = draft.request
        guard !update.isEmpty else { return nil }
        guard begin(original.subCatId) else { return nil }
        defer { end(original.subCatId) }

        do {
            let response = try await client.update(original.subCatId, update)
            if let updated = response.subcategory {
                replace(updated)
            } else {
                await load()
            }
            let newName = response.subcategory?.name ?? update.name ?? original.name
            let change: SubCategoryChange = update.name == nil
                ? .edited(name: original.name)
                : .renamed(from: original.name, to: newName)
            announce(change)
            return nil
        } catch {
            return SubCategoryWording.message(for: error, fallback: SubCategoryWording.saveFailed)
        }
    }

    /// "Delete sub-category": archive it. Returns nil on success, or the
    /// message to show.
    func delete(_ item: SubCategoryItem) async -> String? {
        guard begin(item.subCatId) else { return nil }
        defer { end(item.subCatId) }

        do {
            _ = try await client.archive(item.subCatId)
            // Reload for the archived copy's details; until then move it
            // across as it was, with no notes left on it.
            moveToArchived(item)
            announce(.archived(name: item.name))
            await load()
            return nil
        } catch {
            return SubCategoryWording.message(for: error, fallback: SubCategoryWording.deleteFailed)
        }
    }

    /// Restore an archived sub-category. Returns nil on success, or the
    /// message to show (for example when an active one now has its name).
    func restore(_ item: SubCategoryItem) async -> String? {
        guard begin(item.subCatId) else { return nil }
        defer { end(item.subCatId) }

        do {
            let response = try await client.restore(item.subCatId)
            if let restored = response.subcategory {
                replace(restored)
            } else {
                await load()
            }
            announce(.restored(name: response.subcategory?.name ?? item.name))
            return nil
        } catch {
            return SubCategoryWording.message(for: error, fallback: SubCategoryWording.restoreFailed(item.name))
        }
    }

    // MARK: - List state

    /// Split into active and archived, each sorted by name.
    static func split(_ items: [SubCategoryItem]) -> (active: [SubCategoryItem], archived: [SubCategoryItem]) {
        let sorted = items.sorted { lhs, rhs in
            let order = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            return order == .orderedSame ? lhs.subCatId < rhs.subCatId : order == .orderedAscending
        }
        return (sorted.filter { !$0.archived }, sorted.filter(\.archived))
    }

    private func show(_ items: [SubCategoryItem]) {
        let lists = Self.split(items)
        active = lists.active
        archived = lists.archived
    }

    private func replace(_ updated: SubCategoryItem) {
        show(all.filter { $0.subCatId != updated.subCatId } + [updated])
    }

    private func moveToArchived(_ item: SubCategoryItem) {
        replace(SubCategoryItem(
            subCatId: item.subCatId,
            categoryId: item.categoryId,
            name: item.name,
            description: item.description,
            keywords: item.keywords,
            noteCount: 0,
            archived: true,
            archivedAt: item.archivedAt,
            routines: item.routines
        ))
    }

    private func begin(_ id: Int) -> Bool {
        guard !busyIDs.contains(id) else { return false }
        busyIDs.insert(id)
        return true
    }

    private func end(_ id: Int) {
        busyIDs.remove(id)
    }

    private func announce(_ change: SubCategoryChange) {
        change.post(categoryId: categoryId, to: notificationCenter)
        onChange()
    }
}

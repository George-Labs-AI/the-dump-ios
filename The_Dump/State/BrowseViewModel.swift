import Foundation
import Combine

@MainActor
final class BrowseViewModel: ObservableObject {
    struct FolderRow: Identifiable {
        enum Kind {
            case category
            case dateGroup
            case mimeType
        }
        
        let stableID: String?
        let categoryId: Int?
        let kind: Kind
        let name: String
        let count: Int
        
        var id: String { stableID ?? "\(kind)-\(name)" }
    }
    
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var categoryRows: [FolderRow] = []
    @Published private(set) var archivedCategoryRows: [FolderRow] = []
    @Published private(set) var dateGroupRows: [FolderRow] = []
    @Published private(set) var mimeTypeRows: [FolderRow] = []
    @Published private(set) var recentCount: Int = 0
    /// Routines the user has enabled. Zero hides the Routines row entirely —
    /// "the data is the feature flag", same rule as the web nav.
    @Published private(set) var routineCount: Int = 0
    @Published private(set) var routineOpenAskCount: Int = 0
    private var routineSummaryTask: Task<Void, Never>?

    func loadCounts() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        // Fire-and-forget: the routines call never gates isLoading, so a
        // slow or failing routines API leaves Browse exactly as it was.
        refreshRoutineSummary()

        do {
            async let countsTask = NotesService.shared.fetchCounts()
            async let categoriesTask = NotesService.shared.fetchCategories()
            async let recentTask = NotesService.shared.fetchNotes(limit: 10, cursorTime: nil, cursorId: nil)
            let counts = try await countsTask
            let categories = try await categoriesTask
            let recent = try await recentTask
            let categorySections = Self.splitCategoryRows(
                counts: counts,
                categories: categories.categories
            )
            categoryRows = categorySections.active
            archivedCategoryRows = categorySections.archived
            dateGroupRows = Self.sortedDateGroupRows(dict: counts.dateGroupCounts)
            mimeTypeRows = Self.sortedRows(dict: counts.mimeTypeCounts, kind: .mimeType)
            recentCount = recent.notes.count
        } catch {
            errorMessage = error.localizedDescription
            categoryRows = []
            archivedCategoryRows = []
            dateGroupRows = []
            mimeTypeRows = []
            recentCount = 0
        }

        isLoading = false
    }

    /// Refresh the Routines row independently of the folder counts. One
    /// request in flight at a time; any failure (network, 500, decode)
    /// leaves the last known values so the row never flickers.
    private func refreshRoutineSummary() {
        guard routineSummaryTask == nil else { return }
        routineSummaryTask = Task { [weak self] in
            defer { self?.routineSummaryTask = nil }
            do {
                let routines = try await RoutinesService.shared.fetchRoutines().filter { $0.enabled }
                guard let self, !Task.isCancelled else { return }
                self.routineCount = routines.count
                self.routineOpenAskCount = routines.reduce(0) { $0 + ($1.openAskCount ?? 0) }
            } catch {
                // Keep previous values; the row stays hidden for users without routines.
            }
        }
    }

    private static func sortedRows(dict: [String: Int], kind: FolderRow.Kind) -> [FolderRow] {
        dict
            .map { FolderRow(stableID: nil, categoryId: nil, kind: kind, name: $0.key, count: $0.value) }
            // FolderRow.count is an Int property, not a collection
            // swiftlint:disable:next empty_count
            .filter { $0.count > 0 }
            .sorted(by: sortRowsByName)
    }

    private static func splitCategoryRows(
        counts: NoteCountsResponse,
        categories: [CategoryResponse]
    ) -> (active: [FolderRow], archived: [FolderRow]) {
        guard let details = counts.categoryDetails else {
            return (active: [], archived: [])
        }

        return splitCategoryRows(details: details, categories: categories)
    }

    private static func splitCategoryRows(
        details: [CategoryDetail],
        categories: [CategoryResponse]
    ) -> (active: [FolderRow], archived: [FolderRow]) {
        let namesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.categoryId, $0.name) })

        let resolvedRows = details.compactMap { detail -> (row: FolderRow, archived: Bool)? in
            // CategoryDetail.count is an Int property, not a collection
            // swiftlint:disable:next empty_count
            guard detail.count > 0 else { return nil }
            guard let categoryId = detail.categoryID else { return nil }

            let displayName = resolvedCategoryName(
                for: detail,
                namesByID: namesByID
            )

            return (
                row: FolderRow(
                    stableID: "category-\(categoryId)",
                    categoryId: categoryId,
                    kind: .category,
                    name: displayName,
                    count: detail.count
                ),
                archived: detail.isRetired
            )
        }

        let active = resolvedRows
            .filter { !$0.archived }
            .map(\.row)
            .sorted(by: sortRowsByName)

        let archived = resolvedRows
            .filter { $0.archived }
            .map(\.row)
            .sorted(by: sortRowsByName)

        return (active: active, archived: archived)
    }

    private static func sortRowsByName(_ lhs: FolderRow, _ rhs: FolderRow) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func resolvedCategoryName(
        for detail: CategoryDetail,
        namesByID: [Int: String]
    ) -> String {
        if let categoryID = detail.categoryID, let name = namesByID[categoryID] {
            return name
        }

        return detail.categoryName
    }

    private static func sortedDateGroupRows(dict: [String: Int]) -> [FolderRow] {
        let preferredOrder = [
            "Today",
            "Yesterday",
            "This Week",
            "This Month",
            "This Year",
            "All Time"
        ]

        let byName = dict
            .map { FolderRow(stableID: nil, categoryId: nil, kind: .dateGroup, name: $0.key, count: $0.value) }
            // FolderRow.count is an Int property, not a collection
            // swiftlint:disable:next empty_count
            .filter { $0.count > 0 }

        let preferred = preferredOrder.compactMap { name in
            byName.first(where: { $0.name == name })
        }

        let remaining = byName
            .filter { !preferredOrder.contains($0.name) }
            .sorted(by: sortRowsByName)

        return preferred + remaining
    }
}

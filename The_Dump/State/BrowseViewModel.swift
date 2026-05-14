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
    
    func loadCounts() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
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
    
    private static func sortedRows(dict: [String: Int], kind: FolderRow.Kind) -> [FolderRow] {
        dict
            .map { FolderRow(stableID: nil, categoryId: nil, kind: kind, name: $0.key, count: $0.value) }
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

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
        
        let kind: Kind
        let name: String
        let count: Int
        
        var id: String { "\(kind)-\(name)" }
    }
    
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var categoryRows: [FolderRow] = []
    @Published private(set) var dateGroupRows: [FolderRow] = []
    @Published private(set) var mimeTypeRows: [FolderRow] = []
    
    func loadCounts() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            let counts = try await NotesService.shared.fetchCounts()
            categoryRows = Self.sortedRows(dict: counts.categories, kind: .category)
            dateGroupRows = Self.sortedDateGroupRows(dict: counts.date_groups)
            mimeTypeRows = Self.sortedRows(dict: counts.mime_types, kind: .mimeType)
        } catch {
            errorMessage = error.localizedDescription
            categoryRows = []
            dateGroupRows = []
            mimeTypeRows = []
        }
        
        isLoading = false
    }
    
    private static func sortedRows(dict: [String: Int], kind: FolderRow.Kind) -> [FolderRow] {
        dict
            .map { FolderRow(kind: kind, name: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
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
            .map { FolderRow(kind: .dateGroup, name: $0.key, count: $0.value) }
        
        let preferred = preferredOrder.compactMap { name in
            byName.first(where: { $0.name == name })
        }
        
        let remaining = byName
            .filter { !preferredOrder.contains($0.name) }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        
        return preferred + remaining
    }
}

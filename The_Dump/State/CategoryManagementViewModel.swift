import Foundation
import SwiftUI
import Combine

@MainActor
final class CategoryManagementViewModel: ObservableObject {
    @Published var active: [CategoryListItem] = []
    @Published var archived: [CategoryListItem] = []
    @Published var recentlyDeleted: [CategoryListItem] = []
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?

    var atCap: Bool { active.count >= CategoryLimits.maxActiveCategories }

    /// Names that should block re-use when creating a new category — includes
    /// archived categories because the server still owns the name.
    var reservedNames: [String] {
        (active + archived).map { $0.name }
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            async let userCategories = NotesService.shared.fetchCategories()
            async let noteCounts = NotesService.shared.fetchCounts()

            let (categoriesResponse, countsResponse) = try await (userCategories, noteCounts)
            let countsByName = countsResponse.categories

            let allItems = categoriesResponse.categories.map { resp in
                CategoryListItem.make(
                    from: resp,
                    noteCount: countsByName[resp.name] ?? 0
                )
            }

            active = allItems
                .filter { !$0.archived }
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
            archived = allItems
                .filter { $0.archived }
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
            // Recently-deleted is server-driven (retention window). Empty until
            // the backend exposes the list.
            recentlyDeleted = []
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

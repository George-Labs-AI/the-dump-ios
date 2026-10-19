import Foundation
import SwiftUI
import Combine

@MainActor
final class CategoryManagementViewModel: ObservableObject {
    @Published var active: [CategoryListItem] = []
    @Published var archived: [CategoryListItem] = []
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
            let countsByCategoryID = CategoryCountStore.countsByCategoryID(from: countsResponse)

            let allItems = categoriesResponse.categories.map { resp in
                CategoryListItem.make(
                    from: resp,
                    noteCount: CategoryCountStore.noteCount(
                        for: resp.categoryId,
                        countsByCategoryID: countsByCategoryID
                    )
                )
            }

            active = allItems
                .filter { !$0.archived }
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
            archived = allItems
                .filter { $0.archived }
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
            isLoading = false
            moveEmojiFromThisPhone(categories: categoriesResponse.categories)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Sends emoji chosen on this phone before they were saved on the server,
    /// without holding up the list, then shows the ones that moved.
    private func moveEmojiFromThisPhone(categories: [CategoryResponse]) {
        Task { [weak self] in
            let moved = await CategoryEmojiMover.shared.run(categories: categories)
            guard let self, !moved.isEmpty else { return }
            self.active = Self.applying(moved, to: self.active)
            self.archived = Self.applying(moved, to: self.archived)
        }
    }

    private static func applying(_ emojis: [Int: String], to items: [CategoryListItem]) -> [CategoryListItem] {
        items.map { item in
            guard let emoji = emojis[item.id] else { return item }
            var updated = item
            updated.emoji = emoji
            return updated
        }
    }
}

import Foundation

/// Sends the emoji people chose on this phone, from before emoji were saved
/// on the server, up to the server, and forgets each one once it is saved.
/// It runs in the background after the category list loads; an emoji that
/// fails to send stays on the phone and is tried again on a later load.
@MainActor
final class CategoryEmojiMover {
    static let shared = CategoryEmojiMover()

    private let store: CategoryEmojiStore
    private let save: (_ categoryId: Int, _ emoji: String) async throws -> Void
    private var isRunning = false

    init(
        store: CategoryEmojiStore = CategoryEmojiStore(),
        save: @escaping (_ categoryId: Int, _ emoji: String) async throws -> Void = { categoryId, emoji in
            _ = try await NotesService.shared.updateCategory(
                id: categoryId,
                update: CategoryUpdateRequest(emoji: emoji)
            )
        }
    ) {
        self.store = store
        self.save = save
    }

    /// Moves what it can and returns the emoji that were saved, by category
    /// ID, so the caller can show them without loading again.
    @discardableResult
    func run(categories: [CategoryResponse]) async -> [Int: String] {
        // A server from before emoji were saved leaves the key out and would
        // refuse the change, so nothing is sent to it and nothing is dropped.
        guard !isRunning, !categories.isEmpty, categories.allSatisfy(\.sendsEmoji) else { return [:] }
        let local = store.entries
        guard !local.isEmpty else { return [:] }

        isRunning = true
        defer { isRunning = false }

        let plan = CategoryEmojiMove.plan(
            local: local,
            server: categories.map {
                CategoryEmojiMove.ServerCategory(id: $0.categoryId, emoji: $0.emoji, archived: $0.archived ?? false)
            }
        )
        for categoryId in plan.drop {
            store.remove(categoryId)
        }

        var moved: [Int: String] = [:]
        for (categoryId, emoji) in plan.send.sorted(by: { $0.key < $1.key }) {
            do {
                try await save(categoryId, emoji)
                store.remove(categoryId)
                moved[categoryId] = emoji
            } catch APIError.badRequest(_) {
                // The server refused this emoji, so it can never move.
                store.remove(categoryId)
            } catch {
                // Kept on the phone and tried again on a later load.
            }
        }
        return moved
    }
}

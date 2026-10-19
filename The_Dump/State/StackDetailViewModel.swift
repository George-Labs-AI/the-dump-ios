import Foundation
import Combine

/// One stack opened from a notes list: its notes (GET /api/stack/<id>) and
/// Unstack.
@MainActor
final class StackDetailViewModel: ObservableObject {
    @Published private(set) var title: String?
    @Published private(set) var notes: [NotePreview] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    /// The stack no longer exists (unstacked here or elsewhere, or deleting
    /// notes left it with fewer than 2).
    @Published private(set) var isGone: Bool = false
    @Published private(set) var isUnstacking: Bool = false

    let stackId: String

    init(stackId: String) {
        self.stackId = stackId
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await NotesService.shared.fetchStack(stackId: stackId)
            title = response.stack.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            notes = response.notes
            isGone = false
        } catch APIError.notFound(_) {
            notes = []
            isGone = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// True when the stack was dissolved.
    func unstack() async -> Bool {
        guard !isUnstacking else { return false }
        isUnstacking = true
        errorMessage = nil
        defer { isUnstacking = false }

        do {
            try await NotesService.shared.unstackNotes(stackId: stackId)
            isGone = true
            return true
        } catch APIError.notFound(_) {
            isGone = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

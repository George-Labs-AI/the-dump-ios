import Foundation
import Combine

/// The note types a note can be given: the one list behind the note-detail
/// type picker and the bulk "Change type" action.
///
/// `builtIn` is a copy of the web server's list of note types (same
/// spelling, same order), so the pickers work offline and against a server
/// that doesn't have GET /api/note_types yet. `refresh()` swaps in the
/// server's list when that call succeeds; any failure (a 404, no network, an
/// unexpected body) quietly keeps the list already shown. A list from the
/// server is kept in memory for the rest of the app run.
///
/// Nothing calls `refresh()` at launch: the screens that show a type picker
/// call it when the picker appears. It is cheap to call repeatedly.
@MainActor
final class NoteTypeCatalog: ObservableObject {
    static let shared = NoteTypeCatalog()

    static let builtIn: [String] = [
        "Scratch Capture",
        "To-Do",
        "Checklist",
        "Shopping List",
        "Media List",
        "Recipe",
        "Contact",
        "Resume",
        "Schedule",
        "Reference",
        "Log",
        "Reflection",
        "Inspiration",
        "Reminder",
        "Brainstorm",
        "Content Idea",
        "Draft"
    ]

    @Published private(set) var types: [String] = NoteTypeCatalog.builtIn

    private let fetch: () async throws -> [String]
    private var loadedFromServer = false
    private var inFlight: Task<Void, Never>?

    init(fetch: @escaping () async throws -> [String] = { try await NotesService.shared.fetchNoteTypes() }) {
        self.fetch = fetch
    }

    /// Ask the server for its list, unless it already answered during this
    /// app run. Concurrent calls share one request; after a failure the next
    /// call tries again.
    func refresh() async {
        if loadedFromServer { return }
        if let inFlight {
            await inFlight.value
            return
        }
        let task = Task {
            do {
                if let list = Self.usable(try await fetch()) {
                    types = list
                    loadedFromServer = true
                }
            } catch {
                // Keep the list already shown.
            }
        }
        inFlight = task
        await task.value
        inFlight = nil
    }

    /// The server's list with blank and repeated entries dropped, or nil when
    /// nothing is left (an empty list must not empty the pickers).
    nonisolated static func usable(_ list: [String]) -> [String]? {
        var seen = Set<String>()
        let cleaned = list
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        return cleaned.isEmpty ? nil : cleaned
    }
}

import Foundation
import Combine

@MainActor
final class RoutineDetailViewModel: ObservableObject {
    @Published private(set) var routine: RoutineDetailResponse?
    @Published private(set) var openAsks: [RoutineAsk] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    /// Set when the open-asks request fails. The previous asks are kept so
    /// a failed refresh never wipes the queue or reads as "nothing waiting".
    @Published private(set) var asksErrorMessage: String?

    let slug: String

    init(slug: String) {
        self.slug = slug
    }

    var documents: [RoutineDocumentMeta] {
        guard let docs = routine?.documents else { return [] }
        // sort_order first (nil last), then title — matches the web listing.
        return docs.sorted { a, b in
            switch (a.sortOrder, b.sortOrder) {
            case let (x?, y?) where x != y:
                return x < y
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        }
    }

    func loadIfNeeded() async {
        guard routine == nil else { return }
        await load()
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        asksErrorMessage = nil

        do {
            async let detailTask = RoutinesService.shared.fetchRoutine(slug: slug)
            async let asksTask = RoutinesService.shared.fetchAsks(routineSlug: slug, status: "open")
            routine = try await detailTask
            // The ask queue failing must not hide the documents, and must
            // not discard asks that were already loaded.
            do {
                openAsks = try await asksTask
            } catch {
                asksErrorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Called when the asks screen answers something so the "Needs You"
    /// preview stays honest without a full reload.
    func removeAnswered(askID: String) {
        openAsks.removeAll { $0.askID == askID }
    }
}

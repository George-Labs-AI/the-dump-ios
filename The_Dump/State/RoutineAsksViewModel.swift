import Foundation
import Combine

@MainActor
final class RoutineAsksViewModel: ObservableObject {
    @Published private(set) var asks: [RoutineAsk] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    /// Ask ids with an answer in flight — disables that card's buttons.
    @Published private(set) var submittingAskIDs: Set<String> = []
    /// One-shot notice (e.g. "refreshed after a conflict") for the view to alert.
    @Published var noticeMessage: String?

    let routineSlug: String

    init(routineSlug: String) {
        self.routineSlug = routineSlug
    }

    var openAsks: [RoutineAsk] {
        asks.filter { $0.isOpen }
    }

    /// Everything not open, newest activity first.
    var resolvedAsks: [RoutineAsk] {
        asks.filter { !$0.isOpen }
            .sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") }
    }

    func loadIfNeeded() async {
        guard asks.isEmpty else { return }
        await load()
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            asks = try await RoutinesService.shared.fetchAsks(routineSlug: routineSlug, status: "all")
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Submit an answer. Returns true when the server accepted it. On a
    /// 409 the card is replaced with the server's current row and a notice
    /// is raised — an answer is never silently overwritten (plan §6.4).
    @discardableResult
    func answer(_ ask: RoutineAsk, choice: RoutineAnswerChoice, text: String?) async -> Bool {
        guard !submittingAskIDs.contains(ask.askID) else { return false }
        submittingAskIDs.insert(ask.askID)
        defer { submittingAskIDs.remove(ask.askID) }

        do {
            let updated = try await RoutinesService.shared.answerAsk(
                routineSlug: routineSlug,
                askID: ask.askID,
                choice: choice,
                text: text,
                revision: ask.revision
            )
            replace(updated)
            return true
        } catch let conflict as RoutineAnswerConflict {
            replace(conflict.currentAsk)
            noticeMessage = conflict.errorDescription
            return false
        } catch {
            noticeMessage = error.localizedDescription
            return false
        }
    }

    private func replace(_ updated: RoutineAsk) {
        if let idx = asks.firstIndex(where: { $0.askID == updated.askID }) {
            asks[idx] = updated
        } else {
            asks.append(updated)
        }
    }
}

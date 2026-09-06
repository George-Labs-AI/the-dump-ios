import Foundation
import Combine

@MainActor
final class RoutinesListViewModel: ObservableObject {
    @Published private(set) var routines: [RoutineSummary] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    var totalOpenAsks: Int {
        routines.reduce(0) { $0 + ($1.openAskCount ?? 0) }
    }

    func loadIfNeeded() async {
        guard routines.isEmpty else { return }
        await load()
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await RoutinesService.shared.fetchRoutines()
            routines = fetched
                .filter { $0.enabled }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

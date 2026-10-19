import Foundation
import Combine

/// Loads the runner instructions for one routine (the same text the web's
/// "Connect your runner" page offers to copy).
@MainActor
final class RoutineConnectViewModel: ObservableObject {
    @Published private(set) var instructions: String?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    let slug: String
    private let fetchInstructions: (String) async throws -> String

    init(
        slug: String,
        fetchInstructions: @escaping (String) async throws -> String = {
            try await RoutinesService.shared.fetchRunnerInstructions(routineSlug: $0)
        }
    ) {
        self.slug = slug
        self.fetchInstructions = fetchInstructions
    }

    func loadIfNeeded() async {
        guard instructions == nil else { return }
        await load()
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            instructions = try await fetchInstructions(slug)
        } catch {
            errorMessage = RoutineErrorText.message(for: error)
        }

        isLoading = false
    }
}

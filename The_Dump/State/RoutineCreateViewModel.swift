import Foundation
import Combine

/// The three requests the create flow makes. Swapped out in tests.
struct RoutineCreateClient {
    var scopeOptions: () async throws -> RoutineScopeOptionsResponse
    var preview: (RoutineScope) async throws -> RoutinePreviewResponse
    var create: (RoutineCreateRequest) async throws -> RoutineCreateResponse

    static let live = RoutineCreateClient(
        scopeOptions: { try await RoutinesService.shared.fetchScopeOptions() },
        preview: { try await RoutinesService.shared.previewScope($0) },
        create: { try await RoutinesService.shared.createRoutine($0) }
    )
}

/// One routine being created: a name and description, then the notes it
/// reads, then a preview of those notes, then the create request. Follows
/// the web's "Create a routine" page, including its rule that Create only
/// works once the preview for the current choice has loaded.
@MainActor
final class RoutineCreateViewModel: ObservableObject {
    enum PreviewState: Equatable {
        case idle
        case loading
        case ready(RoutinePreviewResponse)
        case failed(String)
    }

    @Published var name: String = ""
    @Published var description: String = ""
    @Published var selection = RoutineScopeSelection()

    @Published private(set) var options: RoutineScopeOptionsResponse?
    @Published private(set) var isLoadingOptions: Bool = false
    @Published private(set) var optionsError: String?

    @Published private(set) var previewState: PreviewState = .idle
    @Published private(set) var isCreating: Bool = false
    @Published private(set) var createError: String?
    @Published private(set) var createdRoutine: RoutineSummary?

    /// The scope the current preview answers. A reply for an older choice is
    /// dropped, and Create stays off until the preview matches what would be sent.
    private var previewedScope: RoutineScope?
    /// Kept for as long as the body is unchanged, so a retry after a lost
    /// reply finds the routine the first attempt saved instead of making a
    /// second one. Any change to the body gets a new ID, as on the web.
    private var requestBody: RoutineCreateRequest?

    private let client: RoutineCreateClient

    convenience init() {
        self.init(client: .live)
    }

    init(client: RoutineCreateClient) {
        self.client = client
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canContinueFromDetails: Bool {
        !trimmedName.isEmpty
    }

    /// What would be sent for the current ticks, or nil while nothing is
    /// chosen or the categories haven't loaded.
    var scope: RoutineScope? {
        if selection.allNotes { return .allNotes }
        guard let options else { return nil }
        return selection.scope(in: options)
    }

    var canCreate: Bool {
        guard !isCreating, createdRoutine == nil, canContinueFromDetails, let scope else { return false }
        guard case .ready = previewState else { return false }
        return previewedScope == scope
    }

    // MARK: - Step 2: choose notes

    func loadOptionsIfNeeded() async {
        guard options == nil else { return }
        await loadOptions()
    }

    func loadOptions() async {
        guard !isLoadingOptions else { return }
        isLoadingOptions = true
        optionsError = nil
        do {
            options = try await client.scopeOptions()
        } catch {
            optionsError = RoutineErrorText.message(for: error)
        }
        isLoadingOptions = false
    }

    // MARK: - Step 3: preview

    /// Loads the preview for the current choice. Safe to call again after
    /// the choice changed; an answer for an older choice is ignored.
    func loadPreview() async {
        guard let scope else {
            previewedScope = nil
            previewState = .idle
            return
        }
        if previewedScope == scope, case .ready = previewState { return }
        previewedScope = scope
        previewState = .loading
        do {
            let result = try await client.preview(scope)
            guard previewedScope == scope else { return }
            previewState = .ready(result)
        } catch {
            // Leaving the screen cancels the request; that is not a failure
            // to show, and coming back loads the preview again.
            guard previewedScope == scope, !Task.isCancelled else { return }
            previewState = .failed(RoutineErrorText.message(for: error))
        }
    }

    // MARK: - Create

    /// The body to send, reusing the last request ID when nothing changed.
    func makeRequest() -> RoutineCreateRequest? {
        guard let scope, canContinueFromDetails else { return nil }
        let name = trimmedName
        let description = self.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if let previous = requestBody,
           previous.name == name, previous.description == description, previous.scope == scope {
            return previous
        }
        let fresh = RoutineCreateRequest(
            name: name,
            description: description,
            scope: scope,
            requestID: UUID().uuidString.lowercased()
        )
        requestBody = fresh
        return fresh
    }

    func create() async {
        guard canCreate, let body = makeRequest() else { return }
        isCreating = true
        createError = nil
        do {
            let response = try await client.create(body)
            createdRoutine = response.routine
        } catch {
            createError = RoutineErrorText.message(for: error)
        }
        isCreating = false
    }
}

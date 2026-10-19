import XCTest
@testable import The_Dump

/// The create flow's rules: Create works only once the preview for the
/// current choice has loaded, a retry of the same body reuses its request
/// ID, and server messages reach the screen as they are.
// async on purpose: releasing a main-actor object at the end of a
// synchronous test crashes under Xcode 26.
@MainActor
final class RoutineCreateViewModelTests: XCTestCase {
    private struct ServerError: Error {}

    private let options = RoutineScopeOptionsResponse(
        categories: [RoutineScopeCategory(categoryID: 10, name: "Work")],
        subcategories: [RoutineScopeSubcategory(subCategoryID: 20, categoryID: 10, name: "Meetings")]
    )

    private func summary(slug: String = "weekly-brief-1") -> RoutineSummary {
        RoutineSummary(
            routineID: "r1", slug: slug, name: "Weekly brief", description: nil, enabled: true,
            documentCount: nil, openAskCount: 0, updatedAt: nil, status: RoutineStatus(verdict: "UNKNOWN", paused: false)
        )
    }

    /// A view model whose server is a set of closures recording what was sent.
    private func makeViewModel(
        preview: @escaping (RoutineScope) async throws -> RoutinePreviewResponse = { _ in
            RoutinePreviewResponse(count: 0, notes: [])
        },
        create: ((RoutineCreateRequest) async throws -> RoutineCreateResponse)? = nil,
        sent: @escaping (RoutineCreateRequest) -> Void = { _ in }
    ) -> RoutineCreateViewModel {
        let options = self.options
        let created = summary()
        return RoutineCreateViewModel(client: RoutineCreateClient(
            scopeOptions: { options },
            preview: preview,
            create: { body in
                sent(body)
                if let create { return try await create(body) }
                return RoutineCreateResponse(routine: created, created: true, setupURL: nil)
            }
        ))
    }

    func testNameIsRequiredToContinue() async {
        let viewModel = makeViewModel()
        XCTAssertFalse(viewModel.canContinueFromDetails)
        viewModel.name = "   "
        XCTAssertFalse(viewModel.canContinueFromDetails)
        viewModel.name = " Weekly brief "
        XCTAssertTrue(viewModel.canContinueFromDetails)
        XCTAssertEqual(viewModel.trimmedName, "Weekly brief")
    }

    func testCreateStaysOffUntilThePreviewForThisChoiceHasLoaded() async {
        let viewModel = makeViewModel()
        viewModel.name = "Weekly brief"
        await viewModel.loadOptionsIfNeeded()
        XCTAssertNil(viewModel.scope)
        XCTAssertFalse(viewModel.canCreate)

        viewModel.selection.toggleSubcategory(20)
        XCTAssertEqual(viewModel.scope, .selected(categoryIDs: [], subCategoryIDs: [20]))
        XCTAssertFalse(viewModel.canCreate, "no preview yet")

        await viewModel.loadPreview()
        XCTAssertEqual(viewModel.previewState, .ready(RoutinePreviewResponse(count: 0, notes: [])))
        XCTAssertTrue(viewModel.canCreate, "zero matches is fine")

        viewModel.selection.toggleCategory(10)
        XCTAssertFalse(viewModel.canCreate, "the shown preview is for the old choice")
        await viewModel.loadPreview()
        XCTAssertTrue(viewModel.canCreate)
    }

    func testAllNotesNeedsNoCategories() async {
        let viewModel = makeViewModel()
        viewModel.name = "Everything"
        viewModel.selection.allNotes = true
        XCTAssertEqual(viewModel.scope, .allNotes)
        await viewModel.loadPreview()
        XCTAssertTrue(viewModel.canCreate)
    }

    func testPreviewFailureShowsTheServerMessage() async {
        let viewModel = makeViewModel(preview: { _ in
            throw APIError.badRequest(message: "Some selections are unavailable. Reload the categories and select again.")
        })
        viewModel.name = "Weekly brief"
        viewModel.selection.allNotes = true
        await viewModel.loadPreview()
        XCTAssertEqual(
            viewModel.previewState,
            .failed("Some selections are unavailable. Reload the categories and select again.")
        )
        XCTAssertFalse(viewModel.canCreate)
    }

    func testCreateSendsTheTrimmedBodyAndKeepsTheRoutine() async {
        var bodies: [RoutineCreateRequest] = []
        let viewModel = makeViewModel(sent: { bodies.append($0) })
        viewModel.name = "  Weekly brief "
        viewModel.description = "\nKeep a short brief.  "
        await viewModel.loadOptionsIfNeeded()
        viewModel.selection.toggleCategory(10)
        viewModel.selection.toggleSubcategory(20)
        await viewModel.loadPreview()
        await viewModel.create()

        XCTAssertEqual(bodies.count, 1)
        let body = bodies[0]
        XCTAssertEqual(body.name, "Weekly brief")
        XCTAssertEqual(body.description, "Keep a short brief.")
        XCTAssertEqual(body.scope, .selected(categoryIDs: [10], subCategoryIDs: []))
        XCTAssertNotNil(UUID(uuidString: body.requestID))
        XCTAssertEqual(body.requestID, body.requestID.lowercased())
        XCTAssertEqual(viewModel.createdRoutine?.slug, "weekly-brief-1")
        XCTAssertFalse(viewModel.canCreate, "a created routine can't be created again")
    }

    func testRetryAfterAFailureReusesTheRequestIDUntilTheBodyChanges() async {
        var bodies: [RoutineCreateRequest] = []
        var failNext = true
        let created = summary()
        let viewModel = makeViewModel(
            create: { _ in
                if failNext {
                    failNext = false
                    throw APIError.networkError(underlying: URLError(.timedOut))
                }
                return RoutineCreateResponse(routine: created, created: false, setupURL: nil)
            },
            sent: { bodies.append($0) }
        )
        viewModel.name = "Weekly brief"
        viewModel.selection.allNotes = true
        await viewModel.loadPreview()

        await viewModel.create()
        XCTAssertNotNil(viewModel.createError)
        XCTAssertNil(viewModel.createdRoutine)

        await viewModel.create()
        XCTAssertNil(viewModel.createError)
        XCTAssertNotNil(viewModel.createdRoutine)
        XCTAssertEqual(bodies.count, 2)
        XCTAssertEqual(bodies[0].requestID, bodies[1].requestID)
    }

    func testChangedBodyGetsANewRequestID() async {
        let viewModel = makeViewModel()
        viewModel.name = "Weekly brief"
        viewModel.selection.allNotes = true
        let first = viewModel.makeRequest()
        XCTAssertEqual(viewModel.makeRequest()?.requestID, first?.requestID)

        viewModel.name = "Monthly brief"
        let renamed = viewModel.makeRequest()
        XCTAssertNotEqual(renamed?.requestID, first?.requestID)

        await viewModel.loadOptionsIfNeeded()
        viewModel.selection.allNotes = false
        viewModel.selection.toggleCategory(10)
        XCTAssertNotEqual(viewModel.makeRequest()?.requestID, renamed?.requestID)
    }

    func testCreateFailureShowsTheServerMessage() async {
        let viewModel = makeViewModel(create: { _ in
            throw APIError.badRequest(message: "Name must be between 1 and 120 characters.")
        })
        viewModel.name = "Weekly brief"
        viewModel.selection.allNotes = true
        await viewModel.loadPreview()
        await viewModel.create()
        XCTAssertEqual(viewModel.createError, "Name must be between 1 and 120 characters.")
        XCTAssertTrue(viewModel.canCreate, "the user can try again")
    }

    func testOptionsFailureCanBeRetried() async {
        var calls = 0
        let options = self.options
        let viewModel = RoutineCreateViewModel(client: RoutineCreateClient(
            scopeOptions: {
                calls += 1
                if calls == 1 { throw APIError.serverError(message: "Could not load categories. Please try again.") }
                return options
            },
            preview: { _ in RoutinePreviewResponse(count: 0, notes: []) },
            create: { _ in throw ServerError() }
        ))
        await viewModel.loadOptionsIfNeeded()
        XCTAssertEqual(viewModel.optionsError, "Could not load categories. Please try again.")
        XCTAssertNil(viewModel.options)

        await viewModel.loadOptions()
        XCTAssertNil(viewModel.optionsError)
        XCTAssertEqual(viewModel.options, options)
    }

    func testConnectScreenLoadsInstructionsOnceAndCanRetry() async {
        var calls = 0
        let viewModel = RoutineConnectViewModel(slug: "weekly-brief-1") { slug in
            calls += 1
            XCTAssertEqual(slug, "weekly-brief-1")
            if calls == 1 { throw APIError.upstreamFailed(message: "The runner instructions could not be read.") }
            return "# Connect an external runner to The Dump"
        }
        await viewModel.loadIfNeeded()
        XCTAssertEqual(viewModel.errorMessage, "The runner instructions could not be read.")
        XCTAssertNil(viewModel.instructions)

        await viewModel.load()
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.instructions, "# Connect an external runner to The Dump")

        await viewModel.loadIfNeeded()
        XCTAssertEqual(calls, 2, "already loaded")
    }
}

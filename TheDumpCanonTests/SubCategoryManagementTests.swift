import XCTest
@testable import The_Dump

/// Managing sub-categories in Settings: what the server's sub-category
/// object decodes to, the bodies sent to edit, delete and restore one, the
/// words on the delete confirmation (the same as the web's), and the screen's
/// state after each action.
@MainActor
final class SubCategoryManagementTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private func jsonObject(_ data: Data?) throws -> [String: Any] {
        let data = try XCTUnwrap(data)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func item(
        _ id: Int,
        _ name: String,
        description: String? = nil,
        keywords: [String] = [],
        noteCount: Int = 0,
        archived: Bool = false,
        routines: [SubCategoryRoutine] = []
    ) -> SubCategoryItem {
        SubCategoryItem(
            subCatId: id, categoryId: 19, name: name, description: description, keywords: keywords,
            noteCount: noteCount, archived: archived, archivedAt: archived ? "2026-10-01T09:30:00" : nil,
            routines: routines
        )
    }

    // MARK: - The sub-category object

    func testFullObjectDecodes() throws {
        let decoded = try decode(SubCategoryItem.self, """
        {"sub_cat_id": 123, "category_id": 19, "name": "grocery lists", "description": "Weekly shops",
         "keywords": ["milk", "eggs"], "note_count": 7, "archived": false, "archived_at": null,
         "routines": [{"slug": "meal-plan", "name": "Meal plan"}]}
        """)
        XCTAssertEqual(decoded, SubCategoryItem(
            subCatId: 123, categoryId: 19, name: "grocery lists", description: "Weekly shops",
            keywords: ["milk", "eggs"], noteCount: 7, archived: false, archivedAt: nil,
            routines: [SubCategoryRoutine(slug: "meal-plan", name: "Meal plan")]
        ))
        XCTAssertEqual(decoded.id, 123)
    }

    func testOnlyIdAndNameAreRequired() throws {
        let decoded = try decode(SubCategoryItem.self, #"{"sub_cat_id": 5, "name": "receipts"}"#)
        XCTAssertEqual(decoded.subCatId, 5)
        XCTAssertEqual(decoded.name, "receipts")
        XCTAssertNil(decoded.categoryId)
        XCTAssertNil(decoded.description)
        XCTAssertEqual(decoded.keywords, [])
        XCTAssertEqual(decoded.noteCount, 0)
        XCTAssertFalse(decoded.archived)
        XCTAssertNil(decoded.archivedAt)
        XCTAssertEqual(decoded.routines, [])

        XCTAssertThrowsError(try decode(SubCategoryItem.self, #"{"name": "receipts"}"#))
        XCTAssertThrowsError(try decode(SubCategoryItem.self, #"{"sub_cat_id": 5}"#))
    }

    func testUnknownKeysAndNullsAreIgnored() throws {
        let decoded = try decode(SubCategoryItem.self, """
        {"sub_cat_id": "12", "name": "trips", "description": null, "keywords": null, "note_count": null,
         "routines": null, "colour": "blue", "count_of_notes": 99}
        """)
        XCTAssertEqual(decoded.subCatId, 12)
        XCTAssertNil(decoded.description)
        XCTAssertEqual(decoded.keywords, [])
        XCTAssertEqual(decoded.noteCount, 0, "the stale count_of_notes column is never used")
        XCTAssertEqual(decoded.routines, [])
    }

    func testKeywordsSentAsOneStringStillRead() throws {
        let braces = try decode(SubCategoryItem.self, #"{"sub_cat_id": 1, "name": "a", "keywords": "{milk, \"oat milk\", eggs}"}"#)
        XCTAssertEqual(braces.keywords, ["milk", "oat milk", "eggs"])
        let plain = try decode(SubCategoryItem.self, #"{"sub_cat_id": 1, "name": "a", "keywords": " milk , eggs ,"}"#)
        XCTAssertEqual(plain.keywords, ["milk", "eggs"])
    }

    func testArchivedAtAloneMeansArchived() throws {
        // The server sends the categories' format: no time zone.
        let decoded = try decode(SubCategoryItem.self, #"{"sub_cat_id": 1, "name": "a", "archived_at": "2026-10-01T09:30:00"}"#)
        XCTAssertTrue(decoded.archived)
        XCTAssertEqual(decoded.archivedAt, "2026-10-01T09:30:00")
        let explicit = try decode(SubCategoryItem.self, #"{"sub_cat_id": 1, "name": "a", "archived": true}"#)
        XCTAssertTrue(explicit.archived)
    }

    func testRoutineWithoutANameIsNamedBySlug() throws {
        let decoded = try decode(SubCategoryItem.self, """
        {"sub_cat_id": 1, "name": "a", "routines": [{"slug": "meal-plan"}, {"slug": "brief", "name": " "}, 7]}
        """)
        XCTAssertEqual(decoded.routines.map(\.name), ["meal-plan", "brief"])
    }

    func testListSkipsAnUnreadableEntry() throws {
        let decoded = try decode(SubCategoryListResponse.self, """
        {"subcategories": [{"sub_cat_id": 1, "name": "a"}, {"name": "no id"}, {"sub_cat_id": 3, "name": "c", "archived": true}],
         "category_id": 19}
        """)
        XCTAssertEqual(decoded.subcategories.map(\.subCatId), [1, 3])
        XCTAssertEqual(try decode(SubCategoryListResponse.self, "{}").subcategories, [])
    }

    func testActionResponsesDecode() throws {
        let patched = try decode(UpdateSubCategoryResponse.self, """
        {"success": true, "subcategory": {"sub_cat_id": 1, "name": "shopping"}, "notes_renamed": 4}
        """)
        XCTAssertEqual(patched.subcategory?.name, "shopping")
        XCTAssertEqual(patched.notesRenamed, 4)
        XCTAssertEqual(try decode(UpdateSubCategoryResponse.self, #"{"success": true}"#).notesRenamed, 0)

        let archived = try decode(ArchiveSubCategoryResponse.self, #"{"success": true, "notes_updated": 7, "notes_to_recheck": 2}"#)
        XCTAssertEqual(archived, ArchiveSubCategoryResponse(notesUpdated: 7, notesToRecheck: 2))
        XCTAssertEqual(try decode(ArchiveSubCategoryResponse.self, #"{"success": true}"#), ArchiveSubCategoryResponse())

        let restored = try decode(RestoreSubCategoryResponse.self, """
        {"success": true, "subcategory": {"sub_cat_id": 1, "name": "shopping", "archived": false}}
        """)
        XCTAssertEqual(restored.subcategory?.subCatId, 1)
        XCTAssertNil(try decode(RestoreSubCategoryResponse.self, #"{"success": true}"#).subcategory)
    }

    // MARK: - What is sent

    func testListAsksForArchivedOnesToo() throws {
        let endpoint = SubCategoryEndpoint.list(categoryId: 19)
        XCTAssertEqual(endpoint.method, "GET")
        XCTAssertEqual(endpoint.path, "/api/categories/19/subcategories?include_archived=1")
        XCTAssertNil(try endpoint.body())

        let request = try XCTUnwrap(NotesActionRequest.make(
            baseURL: "https://example.com", path: endpoint.path, method: endpoint.method, token: "t", body: nil
        ))
        XCTAssertEqual(request.url?.absoluteString, "https://example.com/api/categories/19/subcategories?include_archived=1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer t")
    }

    func testPatchSendsOnlyTheFieldsGiven() throws {
        let rename = SubCategoryEndpoint.update(subCatId: 123, SubCategoryUpdateRequest(name: "shopping"))
        XCTAssertEqual(rename.method, "PATCH")
        XCTAssertEqual(rename.path, "/api/subcategories/123")
        let renameBody = try jsonObject(rename.body())
        XCTAssertEqual(renameBody["name"] as? String, "shopping")
        XCTAssertEqual(renameBody.count, 1)

        let cleared = try jsonObject(SubCategoryEndpoint.update(
            subCatId: 123, SubCategoryUpdateRequest(description: "", keywords: [])
        ).body())
        XCTAssertEqual(cleared["description"] as? String, "")
        XCTAssertEqual(cleared["keywords"] as? [String], [])
        XCTAssertNil(cleared["name"])
        XCTAssertEqual(cleared.count, 2)

        let all = try jsonObject(SubCategoryEndpoint.update(
            subCatId: 123, SubCategoryUpdateRequest(name: "a", description: "b", keywords: ["c", "d"])
        ).body())
        XCTAssertEqual(all["keywords"] as? [String], ["c", "d"])
        XCTAssertEqual(all.count, 3)
    }

    func testArchiveAndRestoreSendAnEmptyObject() throws {
        let archive = SubCategoryEndpoint.archive(subCatId: 123)
        XCTAssertEqual(archive.method, "POST")
        XCTAssertEqual(archive.path, "/api/subcategories/123/archive")
        XCTAssertEqual(try jsonObject(archive.body()).count, 0)

        let restore = SubCategoryEndpoint.restore(subCatId: 123)
        XCTAssertEqual(restore.method, "POST")
        XCTAssertEqual(restore.path, "/api/subcategories/123/restore")
        XCTAssertEqual(try jsonObject(restore.body()).count, 0)

        let request = try XCTUnwrap(NotesActionRequest.make(
            baseURL: "https://example.com", path: archive.path, method: archive.method, token: "t", body: try archive.body()
        ))
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    // MARK: - Editing rules

    func testUntouchedDraftSendsNothing() {
        let original = item(1, "grocery lists", description: "Weekly", keywords: ["milk"])
        let draft = SubCategoryEditDraft(original)
        XCTAssertEqual(draft.name, "grocery lists")
        XCTAssertEqual(draft.description, "Weekly")
        XCTAssertEqual(draft.keywordsText, "milk")
        XCTAssertTrue(draft.request.isEmpty)
        XCTAssertFalse(draft.canSave(among: [original]))
    }

    func testRenameIsTrimmedAndACaseChangeIsNotARename() {
        let original = item(1, "grocery lists")
        var draft = SubCategoryEditDraft(original)
        draft.name = "  Grocery Lists "
        XCTAssertFalse(draft.isRename, "the server stores names lower-case")
        XCTAssertTrue(draft.request.isEmpty)

        draft.name = "  Shopping "
        XCTAssertTrue(draft.isRename)
        XCTAssertEqual(draft.request, SubCategoryUpdateRequest(name: "shopping"), "sent trimmed and lower-case, as the web does")
        XCTAssertTrue(draft.canSave(among: [original]))
    }

    func testBlankNameCannotBeSaved() {
        let original = item(1, "grocery lists")
        var draft = SubCategoryEditDraft(original)
        draft.name = "   "
        draft.description = "changed"
        XCTAssertTrue(draft.isNameBlank)
        XCTAssertNil(draft.request.name)
        XCTAssertFalse(draft.canSave(among: [original]))
    }

    func testNameUsedByAnotherActiveOrArchivedSubCategoryClashes() {
        let original = item(1, "grocery lists")
        let siblings = [original, item(2, "receipts"), item(3, "old trips", archived: true)]
        var draft = SubCategoryEditDraft(original)

        draft.name = "Receipts"
        XCTAssertEqual(draft.nameClash(among: siblings), "This category already has a sub-category called \"receipts\".")
        XCTAssertFalse(draft.canSave(among: siblings))

        draft.name = " old trips"
        XCTAssertEqual(
            draft.nameClash(among: siblings),
            "This category already has an archived sub-category called \"old trips\". Restore it instead."
        )

        draft.name = "GROCERY LISTS"
        XCTAssertNil(draft.nameClash(among: siblings), "its own name never clashes")

        draft.name = "travel"
        XCTAssertNil(draft.nameClash(among: siblings))
        XCTAssertTrue(draft.canSave(among: siblings))
    }

    func testDescriptionAndKeywordChanges() {
        let original = item(1, "grocery lists", description: "Weekly shops", keywords: ["milk", "eggs"])
        var draft = SubCategoryEditDraft(original)
        XCTAssertEqual(draft.keywordsText, "milk, eggs")

        draft.keywordsText = " milk ,eggs, "
        XCTAssertTrue(draft.request.isEmpty, "spacing and a trailing comma are not a change")

        draft.keywordsText = "milk, bread"
        draft.description = "  "
        XCTAssertEqual(draft.request, SubCategoryUpdateRequest(description: "", keywords: ["milk", "bread"]))

        draft.keywordsText = ""
        XCTAssertEqual(draft.request.keywords, [])
    }

    // MARK: - Words

    func testDeleteConfirmationSingularAndPlural() {
        XCTAssertEqual(
            SubCategoryWording.deleteConfirmation(name: "grocery lists", noteCount: 7),
            "Delete \"grocery lists\"? 7 notes will lose this sub-category. You can restore it later."
        )
        XCTAssertEqual(
            SubCategoryWording.deleteConfirmation(name: "grocery lists", noteCount: 1),
            "Delete \"grocery lists\"? 1 note will lose this sub-category. You can restore it later."
        )
        XCTAssertEqual(
            SubCategoryWording.deleteConfirmation(name: "grocery lists", noteCount: 0),
            "Delete \"grocery lists\"? 0 notes will lose this sub-category. You can restore it later."
        )
    }

    func testOneRoutineWarningPerRoutine() {
        XCTAssertEqual(SubCategoryWording.routineWarnings([]), [])
        XCTAssertEqual(
            SubCategoryWording.routineWarnings([
                SubCategoryRoutine(slug: "meal-plan", name: "Meal plan"),
                SubCategoryRoutine(slug: "budget", name: "Budget")
            ]),
            [
                "Routine Meal plan reads this sub-category. It will stop getting new notes from it.",
                "Routine Budget reads this sub-category. It will stop getting new notes from it."
            ]
        )
    }

    func testDeleteMessageAddsRoutineWarningsAfterTheQuestion() {
        let plain = item(1, "grocery lists", noteCount: 1)
        XCTAssertEqual(
            SubCategoryWording.deleteMessage(for: plain),
            "Delete \"grocery lists\"? 1 note will lose this sub-category. You can restore it later."
        )
        let read = item(1, "grocery lists", noteCount: 2, routines: [
            SubCategoryRoutine(slug: "m", name: "Meal plan"),
            SubCategoryRoutine(slug: "b", name: "Budget")
        ])
        XCTAssertEqual(
            SubCategoryWording.deleteMessage(for: read),
            "Delete \"grocery lists\"? 2 notes will lose this sub-category. You can restore it later.\n\n"
                + "Routine Meal plan reads this sub-category. It will stop getting new notes from it.\n"
                + "Routine Budget reads this sub-category. It will stop getting new notes from it."
        )
    }

    func testServerMessagesAreShownAsTheyAreElseTheWebsFallback() {
        let fallback = SubCategoryWording.saveFailed
        let taken = "This category already has a sub-category called \"x\"."
        XCTAssertEqual(SubCategoryWording.message(for: APIError.conflict(message: taken), fallback: fallback), taken)
        XCTAssertEqual(
            SubCategoryWording.message(for: APIError.badRequest(message: "Name is required."), fallback: fallback),
            "Name is required."
        )
        // No message from the server, a server failure or no answer at all.
        XCTAssertEqual(SubCategoryWording.message(for: APIError.notFound(message: "Unknown error"), fallback: fallback), fallback)
        XCTAssertEqual(SubCategoryWording.message(for: APIError.serverError(message: "Traceback"), fallback: fallback), fallback)
        XCTAssertEqual(SubCategoryWording.message(for: URLError(.notConnectedToInternet), fallback: fallback), fallback)

        XCTAssertEqual(SubCategoryWording.saveFailed, "Could not save the sub-category. Please try again.")
        XCTAssertEqual(SubCategoryWording.deleteFailed, "Could not delete the sub-category. Please try again.")
        XCTAssertEqual(SubCategoryWording.restoreFailed("receipts"), "Couldn't restore \"receipts\". Please try again.")
        XCTAssertEqual(SubCategoryWording.nameTooLong(80), "Sub-category names can be at most 80 characters.")
    }

    // MARK: - Telling other screens

    func testFilterFollowsARenameAndIsDroppedOnDelete() {
        let renamed = SubCategoryChange.renamed(from: "grocery lists", to: "shopping")
        XCTAssertEqual(renamed.selection(after: "Grocery Lists "), "shopping")
        XCTAssertEqual(renamed.selection(after: "receipts"), "receipts")
        XCTAssertNil(renamed.selection(after: nil))

        let archived = SubCategoryChange.archived(name: "grocery lists")
        XCTAssertNil(archived.selection(after: "grocery lists"))
        XCTAssertEqual(archived.selection(after: "receipts"), "receipts")

        XCTAssertEqual(SubCategoryChange.edited(name: "a").selection(after: "a"), "a")
        XCTAssertEqual(SubCategoryChange.restored(name: "a").selection(after: "b"), "b")
    }

    func testChangeNotificationCarriesCategoryAndChange() {
        final class Received: @unchecked Sendable {
            var changes: [(Int, SubCategoryChange)] = []
        }
        let center = NotificationCenter()
        let received = Received()
        let token = center.addObserver(forName: .subCategoriesDidChange, object: nil, queue: nil) { notification in
            if let changed = SubCategoryChange.from(notification) {
                received.changes.append((changed.categoryId, changed.change))
            }
        }
        defer { center.removeObserver(token) }

        SubCategoryChange.renamed(from: "a", to: "b").post(categoryId: 19, to: center)
        XCTAssertEqual(received.changes.count, 1)
        XCTAssertEqual(received.changes.first?.0, 19)
        XCTAssertEqual(received.changes.first?.1, .renamed(from: "a", to: "b"))

        XCTAssertNil(SubCategoryChange.from(Notification(name: .noteWasDeleted, userInfo: ["categoryId": 19])))
    }
}

/// The Settings screen's state for one category's sub-categories, with a
/// stand-in server. Every test is async on purpose: releasing a main-actor
/// object at the end of a synchronous test crashes under Xcode 26.
@MainActor
final class SubCategoryManagementViewModelTests: XCTestCase {
    private struct OtherError: Error {}

    /// Records what the screen sent and answers from fixed replies.
    @MainActor
    private final class FakeServer {
        var items: [SubCategoryItem]
        var listError: Error?
        var updateError: Error?
        var restoreError: Error?
        var updates: [(Int, SubCategoryUpdateRequest)] = []
        var archived: [Int] = []
        var restored: [Int] = []

        init(items: [SubCategoryItem]) {
            self.items = items
        }

        var client: SubCategoryClient {
            SubCategoryClient(
                list: { _ in
                    if let error = self.listError { throw error }
                    return self.items
                },
                update: { id, update in
                    self.updates.append((id, update))
                    if let error = self.updateError { throw error }
                    guard let index = self.items.firstIndex(where: { $0.subCatId == id }) else {
                        throw APIError.notFound(message: "Not found")
                    }
                    let old = self.items[index]
                    let new = SubCategoryItem(
                        subCatId: id, categoryId: old.categoryId, name: update.name ?? old.name,
                        description: update.description ?? old.description, keywords: update.keywords ?? old.keywords,
                        noteCount: old.noteCount, archived: old.archived, archivedAt: old.archivedAt, routines: old.routines
                    )
                    self.items[index] = new
                    return UpdateSubCategoryResponse(subcategory: new, notesRenamed: old.noteCount)
                },
                archive: { id in
                    self.archived.append(id)
                    self.items = self.items.map { item in
                        guard item.subCatId == id else { return item }
                        return SubCategoryItem(subCatId: id, categoryId: item.categoryId, name: item.name, noteCount: 0, archived: true)
                    }
                    return ArchiveSubCategoryResponse(notesUpdated: 3, notesToRecheck: 1)
                },
                restore: { id in
                    self.restored.append(id)
                    if let error = self.restoreError { throw error }
                    guard let index = self.items.firstIndex(where: { $0.subCatId == id }) else {
                        throw APIError.notFound(message: "Not found")
                    }
                    let restored = SubCategoryItem(subCatId: id, categoryId: 19, name: self.items[index].name)
                    self.items[index] = restored
                    return RestoreSubCategoryResponse(subcategory: restored)
                }
            )
        }
    }

    /// Changes announced to other screens, in order.
    private final class Announcements: @unchecked Sendable {
        var changes: [SubCategoryChange] = []
    }

    private let center = NotificationCenter()
    private let announcements = Announcements()
    private var observer: NSObjectProtocol?
    private var posted: [SubCategoryChange] { announcements.changes }

    override func setUp() async throws {
        let announcements = announcements
        announcements.changes = []
        // The view model posts on the main actor, and with no queue the
        // observer runs right there.
        observer = center.addObserver(forName: .subCategoriesDidChange, object: nil, queue: nil) { notification in
            MainActor.assumeIsolated {
                guard let changed = SubCategoryChange.from(notification), changed.categoryId == 19 else { return }
                announcements.changes.append(changed.change)
            }
        }
    }

    override func tearDown() async throws {
        if let observer { center.removeObserver(observer) }
    }

    private func sample() -> [SubCategoryItem] {
        [
            SubCategoryItem(subCatId: 3, categoryId: 19, name: "receipts", noteCount: 2),
            SubCategoryItem(subCatId: 1, categoryId: 19, name: "Grocery lists", noteCount: 7,
                            routines: [SubCategoryRoutine(slug: "m", name: "Meal plan")]),
            SubCategoryItem(subCatId: 9, categoryId: 19, name: "old trips", archived: true)
        ]
    }

    private func makeViewModel(_ server: FakeServer, onChange: @escaping () -> Void = {}) -> SubCategoryManagementViewModel {
        SubCategoryManagementViewModel(categoryId: 19, client: server.client, notificationCenter: center, onChange: onChange)
    }

    func testLoadSplitsActiveFromArchivedSortedByName() async {
        let viewModel = makeViewModel(FakeServer(items: sample()))
        XCTAssertEqual(viewModel.loadState, .loading)
        await viewModel.load()
        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertEqual(viewModel.active.map(\.name), ["Grocery lists", "receipts"])
        XCTAssertEqual(viewModel.archived.map(\.name), ["old trips"])
        XCTAssertEqual(viewModel.all.count, 3)
    }

    func testMissingRouteHidesTheSectionAndOtherErrorsAreShown() async {
        let server = FakeServer(items: [])
        server.listError = APIError.notFound(message: "Unknown error")
        let missing = makeViewModel(server)
        await missing.load()
        XCTAssertEqual(missing.loadState, .unavailable)

        server.listError = APIError.serverError(message: "Down")
        let failing = makeViewModel(server)
        await failing.load()
        XCTAssertEqual(failing.loadState, .failed("Could not load the sub-categories. Try again."))
    }

    func testFailedReloadKeepsWhatIsShown() async {
        let server = FakeServer(items: sample())
        let viewModel = makeViewModel(server)
        await viewModel.load()
        server.listError = OtherError()
        await viewModel.load()
        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertEqual(viewModel.active.count, 2)
    }

    func testRenameSendsOnlyTheNameAndTellsOtherScreens() async throws {
        let server = FakeServer(items: sample())
        var changes = 0
        let viewModel = makeViewModel(server) { changes += 1 }
        await viewModel.load()

        var draft = SubCategoryEditDraft(try XCTUnwrap(viewModel.item(withID: 1)))
        draft.name = " shopping "
        let error = await viewModel.save(draft)

        XCTAssertNil(error)
        XCTAssertEqual(server.updates.map { $0.0 }, [1])
        XCTAssertEqual(server.updates.first?.1, SubCategoryUpdateRequest(name: "shopping"))
        XCTAssertEqual(viewModel.active.map(\.name), ["receipts", "shopping"])
        XCTAssertEqual(posted, [.renamed(from: "Grocery lists", to: "shopping")])
        XCTAssertEqual(changes, 1)
        XCTAssertTrue(viewModel.busyIDs.isEmpty)
    }

    func testDescriptionOnlyEditIsNotARename() async throws {
        let server = FakeServer(items: sample())
        let viewModel = makeViewModel(server)
        await viewModel.load()

        var draft = SubCategoryEditDraft(try XCTUnwrap(viewModel.item(withID: 3)))
        draft.description = "Paper and email receipts"
        let error = await viewModel.save(draft)

        XCTAssertNil(error)
        XCTAssertEqual(server.updates.first?.1, SubCategoryUpdateRequest(description: "Paper and email receipts"))
        XCTAssertEqual(posted, [.edited(name: "receipts")])
    }

    func testClashingNameIsRefusedWithoutAskingTheServer() async throws {
        let server = FakeServer(items: sample())
        let viewModel = makeViewModel(server)
        await viewModel.load()

        var draft = SubCategoryEditDraft(try XCTUnwrap(viewModel.item(withID: 1)))
        draft.name = "Old Trips"
        let error = await viewModel.save(draft)

        XCTAssertEqual(error, SubCategoryWording.archivedNameTaken("old trips"))
        XCTAssertTrue(server.updates.isEmpty)
        XCTAssertTrue(posted.isEmpty)
    }

    func testServerRefusalIsShownAndNothingIsAnnounced() async throws {
        let server = FakeServer(items: sample())
        server.updateError = APIError.conflict(message: "This category already has a sub-category called \"x\".")
        let viewModel = makeViewModel(server)
        await viewModel.load()

        var draft = SubCategoryEditDraft(try XCTUnwrap(viewModel.item(withID: 1)))
        draft.name = "x"
        let error = await viewModel.save(draft)

        XCTAssertEqual(error, "This category already has a sub-category called \"x\".")
        XCTAssertEqual(viewModel.item(withID: 1)?.name, "Grocery lists")
        XCTAssertTrue(posted.isEmpty)
    }

    func testDeleteArchivesAndMovesItToTheArchivedGroup() async throws {
        let server = FakeServer(items: sample())
        var changes = 0
        let viewModel = makeViewModel(server) { changes += 1 }
        await viewModel.load()

        let error = await viewModel.delete(try XCTUnwrap(viewModel.item(withID: 1)))

        XCTAssertNil(error)
        XCTAssertEqual(server.archived, [1])
        XCTAssertEqual(viewModel.active.map(\.subCatId), [3])
        XCTAssertEqual(viewModel.archived.map(\.name), ["Grocery lists", "old trips"])
        XCTAssertEqual(viewModel.item(withID: 1)?.noteCount, 0)
        XCTAssertEqual(posted, [.archived(name: "Grocery lists")])
        XCTAssertEqual(changes, 1)
    }

    func testRestoreBringsItBackToActive() async throws {
        let server = FakeServer(items: sample())
        let viewModel = makeViewModel(server)
        await viewModel.load()

        let error = await viewModel.restore(try XCTUnwrap(viewModel.item(withID: 9)))

        XCTAssertNil(error)
        XCTAssertEqual(server.restored, [9])
        XCTAssertEqual(viewModel.active.map(\.name), ["Grocery lists", "old trips", "receipts"])
        XCTAssertTrue(viewModel.archived.isEmpty)
        XCTAssertEqual(posted, [.restored(name: "old trips")])
    }

    func testRestoreRefusedWhenAnActiveOneHasTheName() async throws {
        let server = FakeServer(items: sample())
        let message = "This category already has a sub-category called \"old trips\"."
        server.restoreError = APIError.conflict(message: message)
        let viewModel = makeViewModel(server)
        await viewModel.load()

        let error = await viewModel.restore(try XCTUnwrap(viewModel.item(withID: 9)))

        XCTAssertEqual(error, message)
        XCTAssertEqual(viewModel.archived.map(\.subCatId), [9])
        XCTAssertTrue(posted.isEmpty)
        XCTAssertTrue(viewModel.busyIDs.isEmpty)
    }

    func testFailuresWithoutAServerMessageUseTheWebsWords() async throws {
        let server = FakeServer(items: sample())
        let viewModel = makeViewModel(server)
        await viewModel.load()

        server.restoreError = URLError(.timedOut)
        let restoreError = await viewModel.restore(try XCTUnwrap(viewModel.item(withID: 9)))
        XCTAssertEqual(restoreError, "Couldn't restore \"old trips\". Please try again.")

        server.updateError = APIError.serverError(message: "Unknown error")
        var draft = SubCategoryEditDraft(try XCTUnwrap(viewModel.item(withID: 3)))
        draft.keywordsText = "tax"
        let saveError = await viewModel.save(draft)
        XCTAssertEqual(saveError, "Could not save the sub-category. Please try again.")
        XCTAssertTrue(posted.isEmpty)
    }
}

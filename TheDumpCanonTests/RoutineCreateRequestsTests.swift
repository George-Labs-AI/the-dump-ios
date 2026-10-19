import XCTest
@testable import The_Dump

/// Request bodies and responses for creating, previewing and pausing a
/// routine, checked against what the web page sends and what the server
/// returns.
@MainActor
final class RoutineCreateRequestsTests: XCTestCase {
    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private let options = RoutineScopeOptionsResponse(
        categories: [
            RoutineScopeCategory(categoryID: 10, name: "Work"),
            RoutineScopeCategory(categoryID: 11, name: "Personal")
        ],
        subcategories: [
            RoutineScopeSubcategory(subCategoryID: 20, categoryID: 10, name: "Meetings"),
            RoutineScopeSubcategory(subCategoryID: 21, categoryID: 10, name: "Project Ideas"),
            RoutineScopeSubcategory(subCategoryID: 22, categoryID: 11, name: "Health")
        ]
    )

    // MARK: - Scope body

    func testAllNotesIsSentOnItsOwn() throws {
        let body = try jsonObject(RoutinePreviewRequest(scope: .allNotes))
        let scope = try XCTUnwrap(body["scope"] as? [String: Any])
        XCTAssertEqual(scope["all_notes"] as? Bool, true)
        XCTAssertEqual(scope.count, 1)
    }

    func testSelectedScopeSendsBothListsAndNothingElse() throws {
        let body = try jsonObject(RoutinePreviewRequest(scope: .selected(categoryIDs: [10], subCategoryIDs: [])))
        let scope = try XCTUnwrap(body["scope"] as? [String: Any])
        XCTAssertEqual(scope["category_ids"] as? [Int], [10])
        XCTAssertEqual(scope["sub_category_ids"] as? [Int], [])
        XCTAssertNil(scope["all_notes"])
        XCTAssertEqual(scope.count, 2)
    }

    // MARK: - Choosing notes

    func testNothingChosenGivesNoScope() {
        XCTAssertNil(RoutineScopeSelection().scope(in: options))
    }

    func testAllNotesOverridesEveryOtherTick() {
        let selection = RoutineScopeSelection(allNotes: true, categoryIDs: [10], subCategoryIDs: [22])
        XCTAssertEqual(selection.scope(in: options), .allNotes)
    }

    func testWholeCategoryDropsItsOwnSubcategories() {
        // 20 is under Work (10), which is chosen whole; 22 is under Personal.
        let selection = RoutineScopeSelection(categoryIDs: [10], subCategoryIDs: [20, 22])
        XCTAssertEqual(selection.scope(in: options), .selected(categoryIDs: [10], subCategoryIDs: [22]))
    }

    func testSubcategoriesOnlyAreSortedAndUnknownIDsDropped() {
        let selection = RoutineScopeSelection(categoryIDs: [999], subCategoryIDs: [22, 20, 12345])
        XCTAssertEqual(selection.scope(in: options), .selected(categoryIDs: [], subCategoryIDs: [20, 22]))
    }

    func testOnlyUnknownIDsGivesNoScope() {
        let selection = RoutineScopeSelection(categoryIDs: [999], subCategoryIDs: [12345])
        XCTAssertNil(selection.scope(in: options))
    }

    func testSubcategoryCanBeChosenOnlyWhenItsCategoryIsNot() {
        let meetings = options.subcategories[0]
        var selection = RoutineScopeSelection()
        XCTAssertTrue(selection.canChooseSubcategory(meetings))
        selection.toggleCategory(10)
        XCTAssertFalse(selection.canChooseSubcategory(meetings))
        selection.toggleCategory(10)
        selection.allNotes = true
        XCTAssertFalse(selection.canChooseSubcategory(meetings))
    }

    func testTogglingTwiceRemovesTheTick() {
        var selection = RoutineScopeSelection()
        selection.toggleSubcategory(22)
        XCTAssertEqual(selection.subCategoryIDs, [22])
        selection.toggleSubcategory(22)
        XCTAssertTrue(selection.subCategoryIDs.isEmpty)
    }

    // MARK: - Create body

    func testCreateBodyHasExactlyTheFourAllowedKeys() throws {
        let body = try jsonObject(RoutineCreateRequest(
            name: "Weekly brief",
            description: "",
            scope: .selected(categoryIDs: [], subCategoryIDs: [22]),
            requestID: "6f1c2c3e-8a9b-4c1d-9e2f-0a1b2c3d4e5f"
        ))
        XCTAssertEqual(Set(body.keys), ["name", "description", "scope", "request_id"])
        XCTAssertEqual(body["name"] as? String, "Weekly brief")
        XCTAssertEqual(body["description"] as? String, "")
        XCTAssertEqual(body["request_id"] as? String, "6f1c2c3e-8a9b-4c1d-9e2f-0a1b2c3d4e5f")
        let scope = try XCTUnwrap(body["scope"] as? [String: Any])
        XCTAssertEqual(scope["sub_category_ids"] as? [Int], [22])
    }

    func testPauseBodyIsJustThePausedFlag() throws {
        XCTAssertEqual(try jsonObject(RoutinePauseRequest(paused: true)) as NSDictionary, ["paused": true])
        XCTAssertEqual(try jsonObject(RoutinePauseRequest(paused: false)) as NSDictionary, ["paused": false])
    }

    // MARK: - Length limits (Python len() counts code points)

    func testLimitsMatchTheServer() {
        XCTAssertEqual(RoutineLimits.maxNameLength, 120)
        XCTAssertEqual(RoutineLimits.maxDescriptionLength, 4000)
        XCTAssertEqual(RoutineLimits.limited(String(repeating: "a", count: 121), to: 120).count, 120)
        XCTAssertEqual(RoutineLimits.limited("Brief", to: 120), "Brief")
    }

    func testSpacesAroundANameDontCountTowardItsLimit() {
        let full = String(repeating: "a", count: 120)
        XCTAssertEqual(RoutineLimits.limitedName("  " + full + " "), "  " + full + " ")
        XCTAssertFalse(RoutineLimits.isNameAtLimit("  " + String(repeating: "a", count: 119) + "  "))
        XCTAssertTrue(RoutineLimits.isNameAtLimit(full))
        XCTAssertEqual(RoutineLimits.limitedName(" " + full + "b"), " " + full)
        // The description is counted as it is, spaces included.
        XCTAssertEqual(RoutineLimits.limited("  abc", to: 4), "  ab")
    }

    func testLimitNeverSplitsAnEmoji() {
        let family = "👨‍👩‍👧" // one character, five code points
        let limited = RoutineLimits.limited(String(repeating: "a", count: 117) + family, to: 120)
        XCTAssertEqual(limited, String(repeating: "a", count: 117))
    }

    // MARK: - Responses (the shapes the server returns)

    func testScopeOptionsDecode() throws {
        let decoded = try decode(RoutineScopeOptionsResponse.self, """
        {"categories": [{"category_id": 11, "name": "Personal"}, {"category_id": 10, "name": "Work"}],
         "subcategories": [{"category_id": 11, "name": "Health", "sub_category_id": 22},
                           {"category_id": 10, "name": "Meetings", "sub_category_id": 20}]}
        """)
        XCTAssertEqual(decoded.categories.map(\.categoryID), [11, 10])
        XCTAssertEqual(decoded.subcategories(of: 10).map(\.name), ["Meetings"])
        XCTAssertEqual(decoded.subcategories(of: 11).first?.subCategoryID, 22)
    }

    func testPreviewDecodesNotesWithMissingTitleOrText() throws {
        let decoded = try decode(RoutinePreviewResponse.self, """
        {"count": 24, "notes": [
          {"note_id": "0d6f3a52-1c4e-4b7a-9f10-2e8c5b7a9d41", "title": "Work meetings", "preview": "# Notes"},
          {"note_id": "c1", "title": null, "preview": null}
        ]}
        """)
        XCTAssertEqual(decoded.count, 24)
        XCTAssertEqual(decoded.notes.count, 2)
        XCTAssertNil(decoded.notes[1].title)
        XCTAssertNil(decoded.notes[1].preview)

        let empty = try decode(RoutinePreviewResponse.self, #"{"count": 0, "notes": []}"#)
        XCTAssertEqual(empty.count, 0)
    }

    func testPreviewCountWording() {
        XCTAssertEqual(RoutinePreviewText.summary(RoutinePreviewResponse(count: 0, notes: [])), "0 matching notes")
        let one = RoutinePreviewNote(noteID: "n1", title: nil, preview: nil)
        XCTAssertEqual(RoutinePreviewText.summary(RoutinePreviewResponse(count: 1, notes: [one])), "1 matching note")
        XCTAssertEqual(
            RoutinePreviewText.summary(RoutinePreviewResponse(count: 24, notes: Array(repeating: one, count: 12))),
            "24 matching notes · showing 12 most recent"
        )
    }

    func testCreateResponseDecodes() throws {
        let decoded = try decode(RoutineCreateResponse.self, """
        {"created": true,
         "routine": {"created_at": "2026-10-19T04:02:54.407569Z", "description": "Keep a brief.",
                     "enabled": true, "latest_scorecard": null, "name": "Weekly brief", "open_ask_count": 0,
                     "routine_id": "6f1c2c3e-8a9b-4c1d-9e2f-0a1b2c3d4e5f", "runner": "external",
                     "scope": {"category_ids": [], "sub_category_ids": [22]},
                     "slug": "weekly-brief-6f1c2c3e8a9b4c1d9e2f0a1b2c3d4e5f",
                     "status": {"as_of": null, "email_sweep": null, "next_expected": "", "open_asks": 0,
                                "paused": false, "reasons": ["Routine registered."], "shift_id": null,
                                "silent_for_hours": 0, "trigger": null, "verdict": "UNKNOWN"},
                     "updated_at": "2026-10-19T04:02:54.407569Z"},
         "setup_url": "/routines/weekly-brief-6f1c2c3e8a9b4c1d9e2f0a1b2c3d4e5f/connect"}
        """)
        XCTAssertEqual(decoded.created, true)
        XCTAssertEqual(decoded.routine.slug, "weekly-brief-6f1c2c3e8a9b4c1d9e2f0a1b2c3d4e5f")
        XCTAssertNil(decoded.routine.documentCount)
        XCTAssertEqual(decoded.routine.status?.paused, false)
        XCTAssertFalse(try XCTUnwrap(decoded.routine.status).isPaused)
        XCTAssertEqual(decoded.setupURL, "/routines/weekly-brief-6f1c2c3e8a9b4c1d9e2f0a1b2c3d4e5f/connect")
    }

    func testPauseReplyDecodesAsASummary() throws {
        // PATCH returns the routine without its documents, so it is not a detail response.
        let decoded = try decode(RoutineSummary.self, """
        {"created_at": "2026-10-19T04:02:54.407569Z", "description": null, "enabled": true,
         "latest_scorecard": null, "name": "Weekly brief", "open_ask_count": 0,
         "routine_id": "r1", "runner": "external", "scope": null, "slug": "weekly-brief",
         "status": {"paused": true, "verdict": "PAUSED", "reasons": []},
         "updated_at": "2026-10-19T04:03:03.561162Z"}
        """)
        XCTAssertEqual(decoded.status?.paused, true)
        XCTAssertTrue(try XCTUnwrap(decoded.status).isPaused)
        XCTAssertEqual(RoutineHealth(status: decoded.status)?.label, "Paused")
    }

    func testPausedFallsBackToTheVerdictWhenTheFlagIsMissing() {
        XCTAssertTrue(RoutineStatus(verdict: "PAUSED").isPaused)
        XCTAssertFalse(RoutineStatus(verdict: "OK").isPaused)
        XCTAssertFalse(RoutineStatus(verdict: nil).isPaused)
        XCTAssertFalse(RoutineStatus(verdict: "PAUSED", paused: false).isPaused)
    }

    func testOddPausedValueDoesNotFailDecoding() throws {
        let status = try decode(RoutineStatus.self, #"{"verdict": "OK", "paused": "yes"}"#)
        XCTAssertNil(status.paused)
        XCTAssertEqual(status.verdict, "OK")
    }

    // MARK: - Status line

    func testMissingStatusSaysUnavailable() {
        XCTAssertEqual(RoutineStatusDisplay(status: nil), .unavailable)
        XCTAssertEqual(RoutineStatusDisplay.unavailableLabel, "Status unavailable")
        XCTAssertEqual(RoutineStatusDisplay(status: RoutineStatus(verdict: "SILENT")), .health(.silent))
        // A status the app can't read still hides rather than showing a code.
        XCTAssertEqual(RoutineStatusDisplay(status: RoutineStatus(verdict: "NEW_CODE")), .hidden)
        XCTAssertEqual(RoutineStatusDisplay(status: RoutineStatus(verdict: nil)), .hidden)
    }

    // MARK: - Runner instructions page

    func testInstructionsAreReadOutOfTheConnectPage() throws {
        let html = """
        <html><body><details><summary>Read the full runner instructions</summary>
        <label for="runner-instructions">Runner handoff</label>
        <textarea id="runner-instructions" readonly rows="15" spellcheck="false"># Connect an external runner to The Dump

        ```json
        {
          &#34;name&#34;: &#34;Weekly brief&#34;,
          &#34;scope&#34;: null
        }
        ```
        GET https://example.com/api/routines/weekly-brief/notes?since=&lt;cursor&gt;&amp;limit=100
        Don&#39;t put passwords in prompts.</textarea>
        </details><textarea id="other">ignore me</textarea></body></html>
        """
        let text = try XCTUnwrap(RunnerInstructionsPage.instructions(fromHTML: html))
        XCTAssertTrue(text.hasPrefix("# Connect an external runner to The Dump"))
        XCTAssertTrue(text.contains(#""name": "Weekly brief","#))
        XCTAssertTrue(text.contains("notes?since=<cursor>&limit=100"))
        XCTAssertTrue(text.hasSuffix("Don't put passwords in prompts."))
        XCTAssertFalse(text.contains("ignore me"))
    }

    func testEscapedAmpersandIsUnescapedOnlyOnce() {
        XCTAssertEqual(RunnerInstructionsPage.unescape("&amp;lt; &amp;#34; &lt;b&gt;"), "&lt; &#34; <b>")
        XCTAssertEqual(RunnerInstructionsPage.unescape("a & b &unknown; &#x41;&#66;"), "a & b &unknown; AB")
        XCTAssertEqual(RunnerInstructionsPage.unescape("tail &"), "tail &")
    }

    func testPageWithoutInstructionsGivesNil() {
        XCTAssertNil(RunnerInstructionsPage.instructions(fromHTML: "<html><body>Sign in</body></html>"))
        XCTAssertNil(RunnerInstructionsPage.instructions(
            fromHTML: #"<textarea id="runner-instructions" readonly>   </textarea>"#
        ))
        XCTAssertNil(RunnerInstructionsPage.instructions(fromHTML: #"<textarea id="runner-instructions">no end"#))
    }

    func testConnectPageAddress() {
        XCTAssertEqual(RoutineLinks.connectPath(slug: "weekly-brief-1a2b"), "/routines/weekly-brief-1a2b/connect")
        XCTAssertEqual(
            RoutineLinks.connectPageURL(slug: "weekly-brief-1a2b", baseURL: "https://example.com")?.absoluteString,
            "https://example.com/routines/weekly-brief-1a2b/connect"
        )
    }

    // MARK: - Error words

    func testServerMessagesAreShownAsTheyAre() {
        XCTAssertEqual(
            RoutineErrorText.message(for: APIError.badRequest(message: "Select at least one category or subcategory.")),
            "Select at least one category or subcategory."
        )
        XCTAssertEqual(
            RoutineErrorText.message(for: APIError.conflict(message: "This request ID was already used. Start a new creation request.")),
            "This request ID was already used. Start a new creation request."
        )
        XCTAssertEqual(
            RoutineErrorText.message(for: APIError.serverError(message: "Could not load categories. Please try again.")),
            "Could not load categories. Please try again."
        )
    }

    func testRateLimitSignInAndBlankMessagesGetTheWebsWords() {
        XCTAssertEqual(
            RoutineErrorText.message(for: APIError.httpError(statusCode: 429, message: "Unknown error")),
            "Too many requests. Wait a minute and try again."
        )
        XCTAssertEqual(
            RoutineErrorText.message(for: APIError.unauthorized(message: "Invalid token")),
            "Please sign in again, then try again."
        )
        XCTAssertEqual(
            RoutineErrorText.message(for: APIError.serverError(message: "Unknown error")),
            "Request failed. Please try again."
        )
    }
}

import XCTest
@testable import The_Dump

/// The backend's onboarding replies (The_Dump_Backend/app/onboarding/) and
/// the first note's status. Each decodes in full, and with keys missing, so
/// a server that drops a field never fails the whole step.
@MainActor
final class OnboardingResponsesDecodingTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    func testConfig() throws {
        let config = try decode(OnboardingConfig.self, """
        {"flow_version": "voice-v1",
         "life_areas": [{"key": "work", "label": "Work", "question": "Anything at work?"}],
         "try_saying": ["I'm launching a newsletter...", "We've got a baby on the way..."],
         "recording": {"warn_at_s": 540, "hard_stop_s": 600, "max_bytes": 26214400},
         "category_rules": {"min": 3, "max": 8, "prefer": 5, "hard_max": 15, "name_max_chars": 30},
         "catch_all": {"name": "Everything else", "description": "Anything that doesn't belong yet."}}
        """)
        XCTAssertEqual(config.flowVersion, "voice-v1")
        XCTAssertEqual(config.trySaying.count, 2)
        XCTAssertEqual(config.recording, OnboardingRecordingLimits(warnAtSeconds: 540, hardStopSeconds: 600))
        XCTAssertEqual(config.categoryRules, OnboardingCategoryRules(min: 3, hardMax: 15, nameMaxChars: 30))
        XCTAssertEqual(config.catchAll, OnboardingCatchAll(name: "Everything else", description: "Anything that doesn't belong yet."))
    }

    func testConfigWithMissingKeysUsesTheDecidedLimits() throws {
        let config = try decode(OnboardingConfig.self, "{}")
        XCTAssertEqual(config.trySaying, [])
        XCTAssertEqual(config.recording.warnAtSeconds, 540)
        XCTAssertEqual(config.recording.hardStopSeconds, 600)
        XCTAssertEqual(config.categoryRules.min, 3)
        XCTAssertEqual(config.categoryRules.hardMax, 15)
        XCTAssertEqual(config.categoryRules.nameMaxChars, 30)
        XCTAssertNil(config.catchAll)
    }

    func testTranscribe() throws {
        let result = try decode(OnboardingTranscription.self, """
        {"text": "I run a bakery.", "duration_s": 12.4, "model": "gpt-transcribe"}
        """)
        XCTAssertEqual(result.text, "I run a bakery.")
        XCTAssertEqual(result.durationSeconds, 12.4)
        XCTAssertNil(try decode(OnboardingTranscription.self, #"{"text": ""}"#).durationSeconds)
    }

    func testRead() throws {
        let read = try decode(OnboardingReadResult.self, """
        {"items": [{"label": "Newsletter", "heard_phrase": "newsletter"}],
         "names": [{"name": "Priya", "kind": "person", "context": "client at Acme"}],
         "model": "gpt-5-mini"}
        """)
        XCTAssertEqual(read.items, [.init(label: "Newsletter", heardPhrase: "newsletter")])
        XCTAssertEqual(read.names.first?.name, "Priya")
        XCTAssertEqual(read.names.first?.kind, "person")
        XCTAssertEqual(try decode(OnboardingReadResult.self, "{}"), OnboardingReadResult())
    }

    func testCheckWithAndWithoutQuestions() throws {
        let gaps = try decode(OnboardingCheckResult.self, """
        {"summary": "You covered work and a kitchen reno.", "assessment": "some_gaps",
         "likely_categories": ["Work", "Kitchen reno"],
         "missing": [{"area": "family", "reason": "No mention of people at home."}],
         "questions": [{"question": "Anything at home?", "why": "home"},
                       {"question": "Any ideas you keep losing?", "why": "ideas"}],
         "model": "gpt-5-mini"}
        """)
        XCTAssertEqual(gaps.summary, "You covered work and a kitchen reno.")
        XCTAssertEqual(gaps.questions.map(\.question), ["Anything at home?", "Any ideas you keep losing?"])

        let complete = try decode(OnboardingCheckResult.self, """
        {"summary": "You covered a lot.", "assessment": "complete", "likely_categories": [], "missing": [], "questions": []}
        """)
        XCTAssertTrue(complete.questions.isEmpty)
        XCTAssertTrue(try decode(OnboardingCheckResult.self, "{}").questions.isEmpty)
    }

    func testDraft() throws {
        let draft = try decode(OnboardingDraftResponse.self, """
        {"categories": [
            {"name": "Kitchen reno", "description": "Redoing the kitchen.",
             "examples": ["Quotes", "Measurements"], "names": ["Maple St", "Dave (contractor)"]},
            {"name": "Side project ideas"}
         ],
         "model": "gpt-5.4-mini"}
        """)
        XCTAssertEqual(draft.categories.count, 2)
        XCTAssertEqual(draft.categories[0].names, ["Maple St", "Dave (contractor)"])
        XCTAssertEqual(draft.categories[1], OnboardingDraftCard(name: "Side project ideas"))
        XCTAssertTrue(try decode(OnboardingDraftResponse.self, "{}").categories.isEmpty)
    }

    func testDraftRequestEncodesReviseModeOnlyWhenGiven() throws {
        let initial = OnboardingDraftRequest(sessionId: "s1", transcript: "t", answers: [], previousDraft: nil)
        let initialJSON = try XCTUnwrap(String(data: JSONEncoder().encode(initial), encoding: .utf8))
        XCTAssertFalse(initialJSON.contains("previous_draft"))
        XCTAssertTrue(initialJSON.contains("\"session_id\":\"s1\""))

        let revise = OnboardingDraftRequest(
            sessionId: "s1", transcript: "t",
            answers: [OnboardingAnswer(question: "Q", answer: "A")],
            previousDraft: [OnboardingDraftCard(name: "Work", description: "d", examples: [], names: ["Acme"])]
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(revise)) as? [String: Any])
        let previous = try XCTUnwrap(object["previous_draft"] as? [[String: Any]])
        XCTAssertEqual(previous.first?["names"] as? [String], ["Acme"])
        XCTAssertEqual((object["answers"] as? [[String: String]])?.first?["answer"], "A")
    }

    func testCompletedStatusWithTheReasonAndText() throws {
        let response = try decode(FileStatusResponse.self, """
        {"statuses": [{"file_uuid": "f1", "status": "completed", "organized_note_id": "n1",
                       "title": "Q4 retainer", "category_id": 7, "category_name": "Client work",
                       "note_content_preview": "Ask Priya if the Q4 retainer covers the deck",
                       "decision_reason": "A question for a client, which points to Client work."}]}
        """)
        let entry = try XCTUnwrap(response.statuses.first)
        XCTAssertEqual(entry.categoryId, 7)
        XCTAssertEqual(entry.noteContentPreview, "Ask Priya if the Q4 retainer covers the deck")
        XCTAssertEqual(entry.decisionReason, "A question for a client, which points to Client work.")
    }

    func testCompletedStatusFromAServerWithoutTheNewFields() throws {
        let response = try decode(FileStatusResponse.self, """
        {"statuses": [{"file_uuid": "f1", "status": "completed", "organized_note_id": "n1",
                       "title": "Q4 retainer", "category_id": 7, "category_name": "Client work"}]}
        """)
        let entry = try XCTUnwrap(response.statuses.first)
        XCTAssertEqual(entry.categoryName, "Client work")
        XCTAssertNil(entry.noteContentPreview)
        XCTAssertNil(entry.decisionReason)

        let nulls = try decode(FileStatusEntry.self, """
        {"file_uuid": "f1", "status": "completed", "decision_reason": null, "note_content_preview": null}
        """)
        XCTAssertNil(nulls.decisionReason)
    }

    func testFinishPayloadRules() {
        XCTAssertEqual(OnboardingRules.savedDefinition(description: "Redoing the kitchen.", examples: ["Quotes", " quotes ", "Paint colors"]),
                       "Redoing the kitchen. Things like: Quotes, Paint colors.")
        XCTAssertEqual(OnboardingRules.savedDefinition(description: " Work. ", examples: []), "Work.")
        XCTAssertEqual(OnboardingRules.savedDefinition(description: "", examples: ["Receipts"]), "Things like: Receipts.")
        XCTAssertEqual(OnboardingRules.clashingName(in: "You already have a category called \"Work\"."), "Work")
        XCTAssertNil(OnboardingRules.clashingName(in: "Something else went wrong"))
    }

    func testMultipartBodyCarriesTheFieldsAndTheFile() throws {
        let body = OnboardingAPIClient.multipartBody(
            boundary: "B",
            fields: [("kind", "answer"), ("known_names", "Priya"), ("known_names", "Acme")],
            file: .init(field: "file", name: "answer.m4a", type: "audio/m4a", data: Data("AUDIO".utf8))
        )
        let text = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertTrue(text.contains("name=\"kind\"\r\n\r\nanswer\r\n"))
        XCTAssertEqual(text.components(separatedBy: "name=\"known_names\"").count, 3)
        XCTAssertTrue(text.contains("name=\"file\"; filename=\"answer.m4a\"\r\nContent-Type: audio/m4a\r\n\r\nAUDIO\r\n--B--\r\n"))
    }
}

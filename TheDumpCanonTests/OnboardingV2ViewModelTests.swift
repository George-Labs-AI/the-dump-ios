import XCTest
import UIKit
@testable import The_Dump

/// The voice onboarding's rules, run against a fake server: the order of
/// the steps, resuming where the app was closed, which cards can be
/// approved, skipping the questions screen, the questions headline,
/// revising the draft only when an answer was given, going back a screen,
/// the Finish save (catch-all included), the first note's reason line, and
/// a reset from Settings starting again at the first screen. Every test is
/// async on purpose: releasing a main-actor object at the end of a
/// synchronous test crashes under Xcode 26.
@MainActor
final class OnboardingV2ViewModelTests: XCTestCase {
    /// Records what was sent and answers with canned replies.
    @MainActor
    final class FakeServer {
        var readCalls = 0
        var readFailures = 0
        var checkCalls = 0
        var transcribeKinds: [OnboardingTranscribeKind] = []
        /// Awaited before each transcription answers, to hold one in flight.
        var transcribeGate: (() async -> Void)?
        var transcriptText = "I run a newsletter and two clients."
        var heardNames: [OnboardingReadResult.Name] = [.init(name: "Priya", kind: "person", context: nil)]
        var draftRequests: [OnboardingDraftRequest] = []
        var saved: [[The_Dump.Category]] = []
        var saveError: Error?
        var uploadedTexts: [String] = []
        var statuses: [FileStatusEntry] = []
        var moves: [(String, Int)] = []

        var questions: [OnboardingCheckResult.Question] = [
            .init(question: "Anything at home you're keeping track of?", why: nil),
            .init(question: "Any ideas you keep coming back to?", why: nil)
        ]
        var initialCards = [
            OnboardingDraftCard(name: "Newsletter", description: "Signal & Noise.", examples: ["Drafts"], names: ["Signal & Noise"]),
            OnboardingDraftCard(name: "Client work", description: "Work for clients.", examples: [], names: ["Priya", "Acme"]),
            OnboardingDraftCard(name: "Kitchen reno", description: "Redoing the kitchen.", examples: ["Quotes", "Paint colors"], names: ["Dave"])
        ]
        var revisedCards = [
            OnboardingDraftCard(name: "Newsletter", description: "Signal & Noise.", examples: [], names: ["Signal & Noise"]),
            OnboardingDraftCard(name: "Client work", description: "Work for clients.", examples: [], names: ["Priya"]),
            OnboardingDraftCard(name: "Kitchen reno", description: "Redoing the kitchen.", examples: [], names: ["Dave"]),
            OnboardingDraftCard(name: "Kids", description: "School and activities.", examples: [], names: ["Maya"])
        ]

        var config = OnboardingConfig(
            flowVersion: "voice-v1",
            trySaying: ["I'm launching a newsletter..."],
            catchAll: OnboardingCatchAll(name: "Everything else", description: "Anything that doesn't belong anywhere else yet.")
        )
        var configCalls = 0
        var existingCategories: [CategoryResponse] = []
        var restored: [Int] = []
        var restoreError: Error?

        var client: OnboardingClient {
            OnboardingClient(
                config: {
                    self.configCalls += 1
                    return self.config
                },
                transcribe: { _, kind, _, _ in
                    self.transcribeKinds.append(kind)
                    await self.transcribeGate?()
                    return OnboardingTranscription(text: self.transcriptText, durationSeconds: 3)
                },
                read: { _, _ in
                    self.readCalls += 1
                    if self.readFailures > 0 {
                        self.readFailures -= 1
                        throw APIError.upstreamFailed(message: "Read failed")
                    }
                    return OnboardingReadResult(
                        items: [.init(label: "Newsletter", heardPhrase: "newsletter"), .init(label: "Clients", heardPhrase: "Priya at Acme")],
                        names: self.heardNames
                    )
                },
                check: { _, _ in
                    self.checkCalls += 1
                    return OnboardingCheckResult(summary: "You covered work and your newsletter.", assessment: "some_gaps", questions: self.questions)
                },
                draft: { request in
                    self.draftRequests.append(request)
                    return request.previousDraft == nil ? self.initialCards : self.revisedCards
                },
                saveCategories: { categories in
                    self.saved.append(categories)
                    if let error = self.saveError {
                        self.saveError = nil
                        throw error
                    }
                    return try categories.enumerated().map { index, category in
                        try Self.savedResponse(id: 100 + index, category: category)
                    }
                },
                fetchCategories: { self.existingCategories },
                restoreCategory: { id in
                    if let error = self.restoreError { throw error }
                    self.restored.append(id)
                },
                uploadText: { text in
                    self.uploadedTexts.append(text)
                    return "file-1"
                },
                uploadPhoto: { _ in "file-photo" },
                uploadFile: { _ in "file-doc" },
                fileStatus: { uuid in
                    guard !self.statuses.isEmpty else { return FileStatusEntry(fileUuid: uuid, status: "processing") }
                    return self.statuses.removeFirst()
                },
                moveNote: { noteId, categoryId in self.moves.append((noteId, categoryId)) },
                sleep: { _ in }
            )
        }

        static func savedResponse(id: Int, category: The_Dump.Category) throws -> CategoryResponse {
            let keywords = (category.keywords ?? []).map { "\"\($0)\"" }.joined(separator: ",")
            let json = """
            {"category_id": \(id), "name": "\(category.name)", "definition": "", "keywords": [\(keywords)],
             "source": "\(category.source ?? "")", "date_added": "x", "last_modified_date": "x"}
            """
            return try JSONDecoder().decode(CategoryResponse.self, from: Data(json.utf8))
        }
    }

    private var suiteNames: [String] = []

    override func tearDown() async throws {
        for name in suiteNames {
            UserDefaults().removePersistentDomain(forName: name)
        }
        suiteNames = []
        try await super.tearDown()
    }

    private func makeStore() -> OnboardingProgressStore {
        let name = "OnboardingV2ViewModelTests-\(UUID().uuidString)"
        suiteNames.append(name)
        return OnboardingProgressStore(uid: "user-1", defaults: UserDefaults(suiteName: name))
    }

    private func makeViewModel(
        _ server: FakeServer,
        store: OnboardingProgressStore? = nil
    ) -> OnboardingV2ViewModel {
        OnboardingV2ViewModel(client: server.client, store: store ?? makeStore(), recordingDirectory: FileManager.default.temporaryDirectory)
    }

    /// Typed ramble → listening back → names (left as they are) → questions.
    private func reachQuestions(_ viewModel: OnboardingV2ViewModel) async {
        await reachNames(viewModel)
        if viewModel.step == .names {
            await viewModel.continueFromNames()
        }
    }

    /// How sorting works → typed ramble → listening back → the names step.
    private func reachNames(_ viewModel: OnboardingV2ViewModel) async {
        await viewModel.resume()
        viewModel.begin()
        viewModel.continueFromExplainer()
        await viewModel.submitTyped("I run a newsletter, I have two clients, and we're redoing the kitchen.")
    }

    private func reachReview(_ server: FakeServer) async -> OnboardingV2ViewModel {
        server.questions = []
        let viewModel = makeViewModel(server)
        await reachQuestions(viewModel)
        return viewModel
    }

    private func approveAll(_ viewModel: OnboardingV2ViewModel) {
        for card in viewModel.progress.cards {
            viewModel.approveCard(card.id)
        }
    }

    // MARK: - Step order

    func testStepsRunInOrderFromPromiseToQuestions() async {
        let server = FakeServer()
        let viewModel = makeViewModel(server)
        XCTAssertEqual(viewModel.step, .promise)
        await viewModel.resume()
        viewModel.begin()
        XCTAssertEqual(viewModel.step, .explainer, "how sorting works comes first")
        viewModel.continueFromExplainer()
        XCTAssertEqual(viewModel.step, .record)

        await viewModel.submitTyped("I run a newsletter, I have two clients, and we're redoing the kitchen.")
        XCTAssertEqual(viewModel.step, .names, "the names step comes before the questions")
        await viewModel.continueFromNames()
        XCTAssertEqual(viewModel.step, .questions)
        XCTAssertEqual(viewModel.progress.transcriptSource, .typed)
        XCTAssertTrue(server.transcribeKinds.isEmpty, "typed text is never transcribed")
        XCTAssertEqual(server.readCalls, 1)
        XCTAssertEqual(server.checkCalls, 1)
        XCTAssertEqual(viewModel.heardLinesShown, 2)
        XCTAssertTrue(viewModel.isCheckDone)
        XCTAssertEqual(viewModel.progress.followups.map(\.question), server.questions.map(\.question))
    }

    func testQuestionsThenBuildingThenReviewThenDone() async throws {
        let server = FakeServer()
        let viewModel = makeViewModel(server)
        await reachQuestions(viewModel)
        viewModel.skipQuestion(0)
        viewModel.skipQuestion(1)
        await viewModel.buildCategories()
        XCTAssertEqual(viewModel.step, .review)
        XCTAssertEqual(viewModel.progress.cards.map(\.name), ["Newsletter", "Client work", "Kitchen reno"])

        approveAll(viewModel)
        await viewModel.finish()
        XCTAssertEqual(viewModel.step, .done)
    }

    // MARK: - Screen 3

    func testNoQuestionsSkipsTheQuestionsScreen() async {
        let server = FakeServer()
        let viewModel = await reachReview(server)
        XCTAssertEqual(viewModel.step, .review, "no questions goes straight through 3b to the cards")
        XCTAssertTrue(viewModel.progress.followups.isEmpty)
        XCTAssertEqual(server.draftRequests.count, 1, "no answers, so no revise call")
    }

    func testHeadlineMatchesTheNumberOfQuestions() async {
        XCTAssertEqual(OnboardingRules.questionsHeadline(count: 1), "Got it. One quick one.")
        XCTAssertEqual(OnboardingRules.questionsHeadline(count: 2), "Got it. Two quick ones.")

        let server = FakeServer()
        server.questions = [.init(question: "Anything at home?", why: nil)]
        let viewModel = makeViewModel(server)
        await reachQuestions(viewModel)
        XCTAssertEqual(viewModel.questionsHeadline, "Got it. One quick one.")
        XCTAssertEqual(viewModel.questionsBody, "You covered work and your newsletter. Anything else?")
    }

    func testDraftIsRevisedOnlyWhenAnAnswerWasGiven() async {
        let skipped = FakeServer()
        let skippedModel = makeViewModel(skipped)
        await reachQuestions(skippedModel)
        skippedModel.skipQuestion(0)
        await skippedModel.buildCategories()
        XCTAssertEqual(skipped.draftRequests.count, 1, "an unanswered question counts as skipped")
        XCTAssertEqual(skippedModel.progress.followups.map(\.source), [.skipped, .skipped])
        XCTAssertEqual(skippedModel.progress.cards.count, 3)

        let answered = FakeServer()
        let answeredModel = makeViewModel(answered)
        await reachQuestions(answeredModel)
        answeredModel.submitTypedAnswer(0, text: "  Maya's school stuff  ")
        answeredModel.skipQuestion(1)
        await answeredModel.buildCategories()
        XCTAssertEqual(answered.draftRequests.count, 2)
        XCTAssertNil(answered.draftRequests[0].previousDraft, "the first draft starts from the transcript alone")
        XCTAssertEqual(answered.draftRequests[0].answers, [])
        let revise = answered.draftRequests[1]
        XCTAssertEqual(revise.answers, [OnboardingAnswer(question: answered.questions[0].question, answer: "Maya's school stuff")])
        XCTAssertEqual(revise.previousDraft, answered.initialCards)
        XCTAssertEqual(answeredModel.progress.cards.map(\.name), ["Newsletter", "Client work", "Kitchen reno", "Kids"])
    }

    func testSpokenAnswerIsTranscribedWithTheNamesHeard() async throws {
        let server = FakeServer()
        let viewModel = makeViewModel(server)
        await reachQuestions(viewModel)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("answer-\(UUID().uuidString).m4a")
        try Data("audio".utf8).write(to: file)

        viewModel.submitAnswerRecording(0, fileURL: file)
        XCTAssertEqual(viewModel.answerStates[0], .transcribing)
        await viewModel.buildCategories()
        XCTAssertEqual(server.transcribeKinds, [.answer])
        XCTAssertEqual(viewModel.progress.followups[0].source, .voice)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path), "the recording is deleted once it is text")
        XCTAssertEqual(server.draftRequests.count, 2)
    }

    // MARK: - The names step (2h and 2g)

    func testHeardNamesAreListedWithGuessesAndSentAsOneAnswer() async {
        let server = FakeServer()
        server.heardNames = [
            .init(name: "Priya", kind: "person", context: "client at Acme"),
            .init(name: "Pocketly", kind: "other", context: nil)
        ]
        let viewModel = makeViewModel(server)
        await reachNames(viewModel)
        XCTAssertEqual(viewModel.step, .names)
        XCTAssertTrue(viewModel.listsNames, "two names heard, so they're listed (2h)")
        XCTAssertEqual(viewModel.nameRows.map(\.name), ["Priya", "Pocketly"])
        XCTAssertEqual(viewModel.nameRows.map(\.meaning), ["client at Acme", ""], "the AI's guess is filled in")

        let app = viewModel.nameRows[1].id
        viewModel.updateNameRow(app, meaning: " my app ")
        let added = viewModel.addNameRow()
        viewModel.updateNameRow(added, name: "Peter", meaning: "our son.")
        viewModel.addNameRow() // left empty, so it says nothing

        await viewModel.continueFromNames()
        XCTAssertEqual(viewModel.step, .questions)
        viewModel.skipQuestion(0)
        viewModel.skipQuestion(1)
        await viewModel.buildCategories()

        XCTAssertEqual(server.draftRequests.count, 2, "the names answer alone is enough to revise the draft")
        XCTAssertEqual(server.draftRequests[1].answers, [OnboardingAnswer(
            question: OnboardingRules.namesQuestion,
            answer: "Priya: client at Acme. Pocketly: my app. Peter: our son."
        )])
    }

    func testFewerThanTwoNamesShowsTheOpenBoxAndSkipSendsNothing() async {
        let server = FakeServer()
        server.questions = []
        let viewModel = makeViewModel(server)
        await reachNames(viewModel)
        XCTAssertFalse(viewModel.listsNames, "one name heard, so the open box shows (2g)")
        XCTAssertEqual(viewModel.nameRows, [])

        viewModel.updateNamesNote("Peter is our son.")
        await viewModel.skipNames()
        XCTAssertNil(viewModel.progress.namesNote)
        XCTAssertEqual(viewModel.step, .review, "no questions, so straight through 3b")
        XCTAssertEqual(server.draftRequests.count, 1, "nothing to revise with")
    }

    func testTheOpenBoxIsSentAndASpokenNoteIsAddedToIt() async throws {
        let server = FakeServer()
        server.questions = []
        server.transcriptText = "Pocketly is my app."
        let viewModel = makeViewModel(server)
        await reachNames(viewModel)
        viewModel.updateNamesNote("Peter is our son.")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("names-\(UUID().uuidString).m4a")
        try Data("audio".utf8).write(to: file)

        viewModel.submitNamesRecording(fileURL: file)
        XCTAssertEqual(viewModel.namesNoteState, .transcribing)
        await viewModel.continueFromNames()
        XCTAssertEqual(server.transcribeKinds, [.answer])
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path), "the recording is deleted once it is text")
        XCTAssertEqual(server.draftRequests.last?.answers, [OnboardingAnswer(
            question: OnboardingRules.namesQuestion,
            answer: "Peter is our son.\nPocketly is my app."
        )])
    }

    func testNamesAnswerRules() async {
        XCTAssertNil(OnboardingRules.namesAnswer(rows: [], note: "  "))
        XCTAssertNil(
            OnboardingRules.namesAnswer(rows: [OnboardingNameRow(name: "Peter"), OnboardingNameRow(name: " ", meaning: "x")], note: nil),
            "rows need both a name and a meaning"
        )
        let rows = (1...12).map { OnboardingNameRow(name: "N\($0)") }
        XCTAssertEqual(
            OnboardingRules.nameRows(from: OnboardingReadResult(items: [], names: rows.map { .init(name: $0.name, kind: nil, context: nil) })).count,
            OnboardingRules.maxNameRows
        )
    }

    // MARK: - Setting up by hand (4m)

    func testSettingUpByHandSkipsTheTalkingAndFinishesWithThreeCategories() async {
        let server = FakeServer()
        let viewModel = makeViewModel(server)
        await viewModel.resume()
        viewModel.setUpMyself()
        XCTAssertEqual(viewModel.step, .review)
        XCTAssertTrue(viewModel.isManualSetup)
        XCTAssertEqual(viewModel.finishLabel, "Finish · add 3 more")

        XCTAssertNil(viewModel.saveCard(cardId: nil, name: "Dreary Lane House", description: "", names: ["Dreary Lane"], examples: []))
        XCTAssertNil(viewModel.saveCard(cardId: nil, name: "Clients", description: "Client work.", names: ["Acme"], examples: []))
        XCTAssertFalse(viewModel.canFinish)
        XCTAssertNil(viewModel.saveCard(cardId: nil, name: "Newsletter", description: "", names: ["Signal & Noise"], examples: []))
        XCTAssertTrue(viewModel.canFinish, "the description is optional")

        await viewModel.finish()
        XCTAssertEqual(viewModel.step, .done)
        XCTAssertEqual(server.saved.first?.map(\.name), ["Dreary Lane House", "Clients", "Newsletter", "Everything else"])
        XCTAssertEqual(server.draftRequests.count, 0, "no AI drafting by hand")
        XCTAssertEqual(server.readCalls, 0)
    }

    func testACategoryAddedByMistakeCanBeRemovedWhenSettingUpByHand() async {
        let viewModel = makeViewModel(FakeServer())
        await viewModel.resume()
        viewModel.setUpMyself()
        XCTAssertNil(viewModel.saveCard(cardId: nil, name: "Oops", description: "", names: ["typo"], examples: []))
        XCTAssertTrue(viewModel.canRemoveCards, "below the minimum, but set up by hand")

        viewModel.removeCard(viewModel.progress.cards[0].id)
        XCTAssertTrue(viewModel.progress.cards.isEmpty)
        XCTAssertFalse(viewModel.canFinish, "the minimum still blocks Finish")
    }

    func testLettingTheAIDraftKeepsCategoriesAddedByHand() async {
        let server = FakeServer()
        server.questions = []
        let viewModel = makeViewModel(server)
        await viewModel.resume()
        viewModel.setUpMyself()
        viewModel.saveCard(cardId: nil, name: "Kitchen RENO", description: "", names: ["Dreary Lane"], examples: [])
        viewModel.letAIDraft()
        XCTAssertEqual(viewModel.step, .explainer)
        XCTAssertFalse(viewModel.isManualSetup)

        viewModel.continueFromExplainer()
        await viewModel.submitTyped("I run a newsletter, I have two clients, and we're redoing the kitchen.")
        await viewModel.continueFromNames()
        XCTAssertEqual(viewModel.step, .review)
        XCTAssertEqual(
            viewModel.progress.cards.map(\.name),
            ["Kitchen RENO", "Newsletter", "Client work"],
            "the hand-made card comes first, and the drafted one with the same name is dropped"
        )
        XCTAssertTrue(viewModel.progress.cards[0].approved)
        XCTAssertEqual(viewModel.progress.cards[0].names, ["Dreary Lane"])
    }

    func testProgressSavedByTheEarlierBuildStillLoads() async throws {
        let json = #"{"step":"questions","sessionId":"s-1","followups":[],"cards":[],"savedCategories":[]}"#
        let progress = try JSONDecoder().decode(OnboardingProgress.self, from: Data(json.utf8))
        XCTAssertEqual(progress.step, .questions)
        XCTAssertNil(progress.nameRows)
        XCTAssertNil(progress.setupMode)
    }

    // MARK: - Going back (THEDUMP-120)

    func testBackRules() async {
        let back = { (step: OnboardingStep, mode: OnboardingSetupMode?, followups: Bool) in
            OnboardingRules.previousStep(from: step, setupMode: mode, hasFollowups: followups)
        }
        XCTAssertNil(back(.promise, nil, false), "nothing before the first screen")
        XCTAssertEqual(back(.explainer, .talk, false), .promise)
        XCTAssertEqual(back(.record, .talk, false), .explainer)
        XCTAssertEqual(back(.names, .talk, true), .record)
        XCTAssertEqual(back(.questions, .talk, true), .names)
        XCTAssertEqual(back(.review, .talk, true), .questions)
        XCTAssertEqual(back(.review, .talk, false), .names, "no questions were asked, so back to the names step")
        XCTAssertEqual(back(.review, nil, false), .names, "progress saved by an earlier build was talking")
        XCTAssertEqual(back(.review, .manual, false), .promise, "set up by hand, back to the first screen")
        for step in [OnboardingStep.listening, .building, .done, .first] {
            XCTAssertNil(back(step, .talk, true), "no back from \(step)")
        }
    }

    func testBackToTheRambleKeepsItAndChangingNothingCallsNothingAgain() async {
        let server = FakeServer()
        let viewModel = makeViewModel(server)
        await reachQuestions(viewModel)
        viewModel.submitTypedAnswer(0, text: "The kids")
        let transcript = viewModel.progress.transcript

        viewModel.goBack()
        XCTAssertEqual(viewModel.step, .names)
        viewModel.goBack()
        XCTAssertEqual(viewModel.step, .record)
        XCTAssertEqual(viewModel.recordMode, .typing, "their words are shown to add to, not a blank screen")
        XCTAssertEqual(viewModel.typedText, transcript)

        await viewModel.submitTyped(viewModel.typedText)
        XCTAssertEqual(viewModel.step, .names)
        XCTAssertEqual(server.readCalls, 1, "the same words are not read again")
        XCTAssertEqual(server.checkCalls, 1)
        XCTAssertEqual(server.draftRequests.count, 1)
        await viewModel.continueFromNames()
        XCTAssertEqual(viewModel.step, .questions)
        XCTAssertEqual(viewModel.progress.followups[0].answer, "The kids", "the answer is kept")
    }

    func testBackFromTheCardsKeepsThemAndComesBackWithoutDraftingAgain() async {
        let server = FakeServer()
        let viewModel = await reachReview(server)
        let card = viewModel.progress.cards[0]
        viewModel.saveCard(cardId: card.id, name: "Letters", description: "Mine.", names: ["S&N"], examples: [])
        let cards = viewModel.progress.cards

        viewModel.goBack()
        XCTAssertEqual(viewModel.step, .names, "no questions were asked, so back to the names step")
        XCTAssertEqual(viewModel.progress.cards, cards)
        await viewModel.continueFromNames()
        XCTAssertEqual(viewModel.step, .review)
        XCTAssertEqual(viewModel.progress.cards, cards, "the edit is still there")
        XCTAssertEqual(server.draftRequests.count, 1, "nothing changed, so nothing is drafted again")
    }

    func testChangingTheRambleDraftsAgainButKeepsWhatTheyWrote() async {
        let server = FakeServer()
        server.heardNames = [
            .init(name: "Priya", kind: "person", context: "client at Acme"),
            .init(name: "Pocketly", kind: "other", context: nil)
        ]
        let viewModel = makeViewModel(server)
        await reachNames(viewModel)
        viewModel.updateNameRow(viewModel.nameRows[1].id, meaning: "my app")
        await viewModel.continueFromNames()
        viewModel.submitTypedAnswer(0, text: "The kids")
        viewModel.skipQuestion(1)
        await viewModel.buildCategories()
        XCTAssertEqual(viewModel.step, .review)
        let edited = viewModel.progress.cards[2]
        viewModel.saveCard(cardId: edited.id, name: "House", description: "", names: ["Dave"], examples: [])

        viewModel.goBack()
        viewModel.goBack()
        viewModel.goBack()
        XCTAssertEqual(viewModel.step, .record)
        viewModel.typedText += " Also Peter's school."
        await viewModel.submitTyped(viewModel.typedText)
        XCTAssertEqual(server.readCalls, 2, "new words are read again")
        XCTAssertEqual(server.checkCalls, 2)
        XCTAssertEqual(viewModel.step, .names)
        XCTAssertEqual(viewModel.nameRows[1].meaning, "my app", "their names are kept")

        await viewModel.continueFromNames()
        XCTAssertEqual(viewModel.progress.followups[0].answer, "The kids", "their answer is kept")
        await viewModel.buildCategories()
        XCTAssertEqual(viewModel.step, .review)
        XCTAssertEqual(server.draftRequests.last?.transcript, viewModel.progress.transcript)
        XCTAssertEqual(
            viewModel.progress.cards.map(\.name),
            ["House", "Newsletter", "Client work", "Kitchen reno", "Kids"],
            "the edited card comes first; the ones not looked at yet are drafted again"
        )
    }

    func testRecordingMoreAddsToTheWordsAlreadySaved() async throws {
        let server = FakeServer()
        server.questions = []
        let viewModel = makeViewModel(server)
        await reachNames(viewModel)
        viewModel.goBack()
        XCTAssertEqual(viewModel.step, .record)
        viewModel.talkInstead()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("ramble-\(UUID().uuidString).m4a")
        try Data("audio".utf8).write(to: file)

        await viewModel.submitRecording(fileURL: file)
        XCTAssertEqual(server.transcribeKinds, [.ramble])
        XCTAssertEqual(
            viewModel.progress.transcript,
            "I run a newsletter, I have two clients, and we're redoing the kitchen.\n\nI run a newsletter and two clients."
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(server.readCalls, 2)
        XCTAssertEqual(viewModel.step, .names)
    }

    func testASilentRecordingAfterGoingBackKeepsTheSavedWords() async throws {
        let server = FakeServer()
        server.questions = []
        let viewModel = makeViewModel(server)
        await reachNames(viewModel)
        let saved = viewModel.progress.transcript
        viewModel.goBack()
        viewModel.typedText = ""
        viewModel.talkInstead()
        server.transcriptText = "  "
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("ramble-\(UUID().uuidString).m4a")
        try Data("audio".utf8).write(to: file)

        await viewModel.submitRecording(fileURL: file)
        XCTAssertEqual(viewModel.step, .record)
        XCTAssertNotNil(viewModel.recordNotice)
        XCTAssertEqual(viewModel.progress.transcript, saved, "clearing the box and recording silence deletes nothing")
        XCTAssertNotNil(viewModel.progress.extraction, "the AI's results are kept too")
        XCTAssertEqual(server.readCalls, 1)
    }

    func testSetUpByHandGoesBackToTheFirstScreenKeepingTheCards() async {
        let viewModel = makeViewModel(FakeServer())
        await viewModel.resume()
        viewModel.setUpMyself()
        viewModel.saveCard(cardId: nil, name: "Clients", description: "", names: ["Acme"], examples: [])
        viewModel.goBack()
        XCTAssertEqual(viewModel.step, .promise)
        XCTAssertFalse(viewModel.canGoBack, "nothing before the first screen")
        viewModel.setUpMyself()
        XCTAssertEqual(viewModel.progress.cards.map(\.name), ["Clients"])
    }

    func testNoBackAfterFinish() async {
        let viewModel = await reachDone(FakeServer())
        XCTAssertEqual(viewModel.step, .done)
        XCTAssertFalse(viewModel.canGoBack)
        viewModel.goBack()
        XCTAssertEqual(viewModel.step, .done)
    }

    func testALateReplyAfterGoingBackDoesNotMoveThemOn() async throws {
        let server = FakeServer()
        server.questions = []
        let viewModel = makeViewModel(server)
        await reachNames(viewModel)
        var release: CheckedContinuation<Void, Never>?
        server.transcribeGate = { await withCheckedContinuation { release = $0 } }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("names-\(UUID().uuidString).m4a")
        try Data("audio".utf8).write(to: file)

        viewModel.submitNamesRecording(fileURL: file)
        let continuing = Task { await viewModel.continueFromNames() }
        while release == nil {
            await Task.yield()
        }
        viewModel.goBack()
        XCTAssertEqual(viewModel.step, .record)
        release?.resume()
        await continuing.value
        XCTAssertEqual(viewModel.step, .record, "they stay where they went")
        XCTAssertEqual(viewModel.namesNote, "I run a newsletter and two clients.", "the spoken note still lands")
        XCTAssertEqual(server.draftRequests.count, 1, "nothing was built")
    }

    // MARK: - Failures and resuming

    func testAFailedStepIsRetriedOnceThenShownAndRetriedFromWhatWasSaved() async {
        let server = FakeServer()
        server.readFailures = 2
        let viewModel = makeViewModel(server)
        await reachQuestions(viewModel)
        XCTAssertEqual(viewModel.step, .listening)
        XCTAssertEqual(viewModel.progress.failure?.task, .read)
        XCTAssertEqual(server.readCalls, 2, "retried once on its own")
        XCTAssertNotNil(viewModel.progress.transcript, "what they said is kept")

        await viewModel.retryFailedStep()
        XCTAssertNil(viewModel.progress.failure)
        XCTAssertEqual(viewModel.step, .names)
        XCTAssertEqual(server.checkCalls, 1, "the check already finished, so only read re-runs")
    }

    func testResumesAtTheSavedStep() async {
        let store = makeStore()
        let first = FakeServer()
        let viewModel = makeViewModel(first, store: store)
        await reachQuestions(viewModel)
        viewModel.submitTypedAnswer(0, text: "The kids")

        let again = FakeServer()
        let resumed = makeViewModel(again, store: store)
        XCTAssertEqual(resumed.step, .questions)
        XCTAssertEqual(resumed.progress.followups[0].answer, "The kids")
        XCTAssertEqual(resumed.progress.sessionId, viewModel.progress.sessionId)
        await resumed.resume()
        XCTAssertEqual(again.readCalls, 0, "finished steps are not run again")
        XCTAssertEqual(again.checkCalls, 0)
    }

    func testResumeMidListeningRunsOnlyWhatIsLeft() async {
        let store = makeStore()
        var progress = OnboardingProgress()
        progress.step = .listening
        progress.transcript = "I run a newsletter."
        progress.extraction = OnboardingReadResult(items: [.init(label: "N", heardPhrase: "newsletter")], names: [])
        store.save(progress)

        let server = FakeServer()
        let viewModel = makeViewModel(server, store: store)
        await viewModel.resume()
        XCTAssertEqual(server.readCalls, 0)
        XCTAssertEqual(server.checkCalls, 1)
        XCTAssertEqual(viewModel.step, .names)
    }

    func testResumeWithAnUnsentRecordingTranscribesItAndDeletesIt() async throws {
        let store = makeStore()
        let name = "ramble-\(UUID().uuidString).m4a"
        try Data("audio".utf8).write(to: FileManager.default.temporaryDirectory.appendingPathComponent(name))
        var progress = OnboardingProgress()
        progress.step = .listening
        progress.pendingRecordingName = name
        store.save(progress)

        let server = FakeServer()
        let viewModel = makeViewModel(server, store: store)
        await viewModel.resume()
        XCTAssertEqual(server.transcribeKinds, [.ramble])
        XCTAssertEqual(viewModel.progress.transcript, "I run a newsletter and two clients.")
        XCTAssertNil(viewModel.progress.pendingRecordingName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: FileManager.default.temporaryDirectory.appendingPathComponent(name).path))
    }

    func testASilentRecordingGoesBackToRecordingWithANotice() async throws {
        let server = FakeServer()
        server.transcriptText = "  "
        let viewModel = makeViewModel(server)
        await viewModel.resume()
        viewModel.begin()
        viewModel.continueFromExplainer()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("ramble-\(UUID().uuidString).m4a")
        try Data("audio".utf8).write(to: file)
        await viewModel.submitRecording(fileURL: file)
        XCTAssertEqual(viewModel.step, .record)
        XCTAssertNotNil(viewModel.recordNotice)
        XCTAssertNil(viewModel.progress.transcript)
        XCTAssertEqual(server.readCalls, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testFinishedButNotLeftKeepsTheOnboardingOnScreen() async {
        let store = makeStore()
        XCTAssertFalse(store.hasFinishedButNotLeft)
        var progress = OnboardingProgress()
        progress.step = .review
        store.save(progress)
        XCTAssertFalse(store.hasFinishedButNotLeft)
        progress.step = .done
        store.save(progress)
        XCTAssertTrue(store.hasFinishedButNotLeft)

        let viewModel = makeViewModel(FakeServer(), store: store)
        viewModel.leave()
        XCTAssertNil(store.load())
        viewModel.begin()
        XCTAssertNil(store.load(), "a late change after leaving is not saved again")
    }

    // MARK: - Screen 4: approving and editing

    func testCardWithoutNamesCannotBeApprovedAndFinishWaitsForEveryCard() async {
        let server = FakeServer()
        server.initialCards[2] = OnboardingDraftCard(name: "Kids", description: "", examples: [], names: [])
        let viewModel = await reachReview(server)
        XCTAssertEqual(viewModel.finishLabel, "Finish · 3 left")
        XCTAssertFalse(viewModel.canFinish)

        let cards = viewModel.progress.cards
        viewModel.approveCard(cards[0].id)
        viewModel.approveCard(cards[1].id)
        viewModel.approveCard(cards[2].id)
        XCTAssertFalse(viewModel.progress.cards[2].approved, "no names, so it can't be approved")
        XCTAssertEqual(viewModel.finishLabel, "Finish · 1 left")
        XCTAssertEqual(viewModel.openCardId, cards[2].id, "the card still needing attention is open")

        viewModel.addChip(" Maya ", to: .names, cardId: cards[2].id)
        viewModel.approveCard(cards[2].id)
        XCTAssertTrue(viewModel.canFinish)
        XCTAssertEqual(viewModel.finishLabel, "Finish")
    }

    func testEditRulesAndRemoveStopsAtThree() async {
        let server = FakeServer()
        let viewModel = await reachReview(server)
        let card = viewModel.progress.cards[0]

        XCTAssertEqual(viewModel.saveCard(cardId: card.id, name: " ", description: "", names: ["a"], examples: [])?.name, "Give it a name.")
        XCTAssertNotNil(viewModel.saveCard(cardId: card.id, name: String(repeating: "x", count: 31), description: "", names: ["a"], examples: [])?.name)
        XCTAssertEqual(
            viewModel.saveCard(cardId: card.id, name: " client WORK ", description: "", names: ["a"], examples: [])?.name,
            "You already have a category called Client work.",
            "names clash ignoring case and spaces"
        )
        XCTAssertNotNil(viewModel.saveCard(cardId: card.id, name: "everything else", description: "", names: ["a"], examples: [])?.name, "the catch-all's name is taken")
        let noNames = viewModel.saveCard(cardId: card.id, name: "Letters", description: "", names: ["  "], examples: [])
        XCTAssertNil(noNames?.name)
        XCTAssertEqual(noNames?.names, "Add at least one keyword so notes can find this category.")
        XCTAssertNil(viewModel.saveCard(cardId: card.id, name: " Letters ", description: "Mine.", names: ["S&N", "s&n"], examples: []))
        XCTAssertEqual(viewModel.progress.cards[0].name, "Letters")
        XCTAssertEqual(viewModel.progress.cards[0].names, ["S&N"])
        XCTAssertTrue(viewModel.progress.cards[0].approved, "Save approves the card")

        XCTAssertFalse(viewModel.canRemoveCards, "Remove is hidden at three cards")
        viewModel.removeCard(card.id)
        XCTAssertEqual(viewModel.progress.cards.count, 3)

        XCTAssertNil(viewModel.saveCard(cardId: nil, name: "Kids", description: "", names: ["Maya"], examples: []))
        XCTAssertEqual(viewModel.progress.cards.count, 4)
        XCTAssertTrue(viewModel.canRemoveCards)
        viewModel.removeCard(card.id)
        XCTAssertEqual(viewModel.progress.cards.count, 3)
    }

    // MARK: - Finish

    func testFinishSavesEveryCardAndTheCatchAllInOneRequest() async {
        let server = FakeServer()
        let viewModel = await reachReview(server)
        approveAll(viewModel)
        await viewModel.finish()

        XCTAssertEqual(server.saved.count, 1)
        let payload = server.saved[0]
        XCTAssertEqual(payload.map(\.name), ["Newsletter", "Client work", "Kitchen reno", "Everything else"])
        XCTAssertEqual(payload[0].definition, "Signal & Noise. Things like: Drafts.")
        XCTAssertEqual(payload[1].definition, "Work for clients.", "no examples, no \"Things like\"")
        XCTAssertEqual(payload[2].definition, "Redoing the kitchen. Things like: Quotes, Paint colors.")
        XCTAssertEqual(payload[1].keywords, ["Priya", "Acme"])
        XCTAssertEqual(payload.prefix(3).map(\.source), Array(repeating: "onboarding_voice", count: 3))
        XCTAssertEqual(payload[3].definition, server.config.catchAll?.description)
        XCTAssertEqual(payload[3].keywords, [])
        XCTAssertEqual(payload[3].source, "onboarding_catchall")

        XCTAssertEqual(viewModel.step, .done)
        XCTAssertEqual(viewModel.savedCategoryCount, 4)
        XCTAssertEqual(viewModel.savedNameCount, 4)
        XCTAssertEqual(viewModel.savedCategoryLine, "Newsletter · Client work · Kitchen reno · Everything else")
        XCTAssertEqual(viewModel.progress.savedCategories.last?.isCatchAll, true)
    }

    func testANameClashIsShownOnItsCard() async {
        let server = FakeServer()
        let viewModel = await reachReview(server)
        approveAll(viewModel)
        server.saveError = APIError.conflict(message: "You already have an archived category called \"client work\". Restore it instead of creating a new one.")
        await viewModel.finish()

        XCTAssertEqual(viewModel.step, .review)
        let card = viewModel.progress.cards[1]
        XCTAssertEqual(card.errorMessage, "You already have an archived category called \"client work\". Restore it instead of creating a new one.")
        XCTAssertFalse(card.approved)
        XCTAssertEqual(viewModel.openCardId, card.id)
        XCTAssertNil(viewModel.finishError)
        XCTAssertFalse(viewModel.canFinish)
    }

    func testFinishFetchesTheConfigAgainWhenItHasNoCatchAll() async {
        let server = FakeServer()
        let catchAll = server.config.catchAll
        server.config = OnboardingConfig(flowVersion: "voice-v1")
        let viewModel = await reachReview(server)
        approveAll(viewModel)
        await viewModel.finish()
        XCTAssertEqual(viewModel.step, .review)
        XCTAssertNotNil(viewModel.finishError)
        XCTAssertTrue(server.saved.isEmpty, "nothing is saved without the catch-all")

        server.config = OnboardingConfig(flowVersion: "voice-v1", catchAll: catchAll)
        let callsBefore = server.configCalls
        await viewModel.finish()
        XCTAssertEqual(server.configCalls, callsBefore + 1, "tapping Finish again fetches the config again")
        XCTAssertEqual(viewModel.step, .done)
        XCTAssertEqual(server.saved.last?.last?.name, "Everything else")
    }

    func testAnArchivedCatchAllIsRestoredAndAFailedRestoreStillFinishes() async throws {
        let archived = try FakeServer.savedResponse(id: 77, category: The_Dump.Category(name: "Everything else"))
        let clash = APIError.conflict(message: "You already have an archived category called \"Everything else\". Restore it instead of creating a new one.")

        let server = FakeServer()
        server.existingCategories = [archived]
        let viewModel = await reachReview(server)
        approveAll(viewModel)
        server.saveError = clash
        await viewModel.finish()
        XCTAssertEqual(viewModel.step, .done)
        XCTAssertEqual(server.saved.last?.map(\.name), ["Newsletter", "Client work", "Kitchen reno"], "saved without the catch-all")
        XCTAssertEqual(server.restored, [77])
        XCTAssertEqual(viewModel.progress.savedCategories.last?.id, 77)
        XCTAssertEqual(viewModel.progress.savedCategories.last?.isCatchAll, true)

        let failing = FakeServer()
        failing.existingCategories = [archived]
        failing.restoreError = APIError.serverError(message: "down")
        let stuck = await reachReview(failing)
        approveAll(stuck)
        failing.saveError = clash
        await stuck.finish()
        XCTAssertEqual(stuck.step, .done, "the cards are saved, so a failed restore doesn't leave them on screen 4")
        XCTAssertEqual(stuck.progress.savedCategories.count, 3)
    }

    func testCancelledRequestsAreNotRetried() {
        XCTAssertFalse(OnboardingV2ViewModel.isRetryable(CancellationError()))
        XCTAssertFalse(OnboardingV2ViewModel.isRetryable(APIError.networkError(underlying: URLError(.cancelled))))
        XCTAssertFalse(OnboardingV2ViewModel.isRetryable(APIError.networkError(underlying: CancellationError())))
        XCTAssertTrue(OnboardingV2ViewModel.isRetryable(APIError.networkError(underlying: URLError(.timedOut))))
        XCTAssertTrue(OnboardingV2ViewModel.isRetryable(APIError.upstreamFailed(message: "x")))
        XCTAssertFalse(OnboardingV2ViewModel.isRetryable(APIError.conflict(message: "x")))
        XCTAssertFalse(OnboardingV2ViewModel.isRetryable(APIError.badRequest(message: "x")))
    }

    // MARK: - Screen 6

    private func reachDone(_ server: FakeServer) async -> OnboardingV2ViewModel {
        let viewModel = await reachReview(server)
        approveAll(viewModel)
        await viewModel.finish()
        return viewModel
    }

    func testFirstNoteShowsTheReasonUntilTheCategoryIsChanged() async {
        let server = FakeServer()
        let viewModel = await reachDone(server)
        server.statuses = [
            FileStatusEntry(fileUuid: "file-1", status: "processing"),
            FileStatusEntry(fileUuid: "file-1", status: "transcribed", noteContentPreview: "Ask Priya about Q4"),
            FileStatusEntry(
                fileUuid: "file-1", status: "completed", noteContentPreview: "Ask Priya about the Q4 retainer",
                organizedNoteId: "note-9", categoryId: 101, categoryName: "Client work",
                decisionReason: "A question for a client."
            )
        ]

        await viewModel.submitFirstText("  Ask Priya about the Q4 retainer ")
        XCTAssertEqual(server.uploadedTexts, ["Ask Priya about the Q4 retainer"])
        XCTAssertEqual(viewModel.step, .first)
        await viewModel.pollFirstNote()

        let note = viewModel.progress.firstNote
        XCTAssertEqual(note?.status, .sorted)
        XCTAssertEqual(note?.displayText, "Ask Priya about the Q4 retainer")
        XCTAssertEqual(note?.visibleReason, "A question for a client.")
        let saved = viewModel.progress.savedCategories
        XCTAssertEqual(saved.filter { viewModel.isFirstNoteCategory($0) }.map(\.name), ["Client work"])

        let kitchen = saved[2]
        await viewModel.changeFirstNoteCategory(to: kitchen)
        XCTAssertEqual(server.moves.first?.0, "note-9")
        XCTAssertEqual(server.moves.first?.1, kitchen.id)
        XCTAssertNil(viewModel.progress.firstNote?.visibleReason, "the reason no longer matches")
        XCTAssertTrue(viewModel.isFirstNoteCategory(kitchen))
    }

    func testFirstNoteWithoutAReasonLeavesTheLineOut() async {
        let server = FakeServer()
        let viewModel = await reachDone(server)
        server.statuses = [
            FileStatusEntry(fileUuid: "file-1", status: "completed", organizedNoteId: "note-9", categoryId: 103, categoryName: "Everything else")
        ]
        await viewModel.submitFirstText("Buy stamps")
        await viewModel.pollFirstNote()
        XCTAssertEqual(viewModel.progress.firstNote?.status, .sorted)
        XCTAssertNil(viewModel.progress.firstNote?.visibleReason)
        XCTAssertEqual(viewModel.progress.firstNote?.displayText, "Buy stamps", "falls back to what was typed")
    }

    func testFirstNoteThatFailsStopsPolling() async {
        let server = FakeServer()
        let viewModel = await reachDone(server)
        server.statuses = [FileStatusEntry(fileUuid: "file-1", status: "failed", error: "unreadable")]
        await viewModel.submitFirstText("Something")
        await viewModel.pollFirstNote()
        XCTAssertEqual(viewModel.progress.firstNote?.status, .failed)
    }

    // MARK: - Resetting onboarding from Settings (test accounts)

    func testResetForgetsProgressSoTheFlowStartsAtThePromise() async {
        let store = makeStore()
        var progress = OnboardingProgress()
        progress.step = .first
        store.save(progress)
        let defaultsName = "OnboardingV2ViewModelTests-\(UUID().uuidString)"
        suiteNames.append(defaultsName)
        let defaults = UserDefaults(suiteName: defaultsName) ?? .standard
        defaults.set(true, forKey: "onboarding_completed_user-1")
        XCTAssertTrue(store.hasFinishedButNotLeft)

        AppState.forgetOnboarding(uid: "user-1", store: store, defaults: defaults)

        XCTAssertNil(store.load())
        XCTAssertFalse(store.hasFinishedButNotLeft, "screens 5 and 6 are not resumed")
        XCTAssertFalse(defaults.bool(forKey: "onboarding_completed_user-1"))
        let viewModel = makeViewModel(FakeServer(), store: store)
        XCTAssertEqual(viewModel.step, .promise)
    }

    func testResetFailureMessages() async {
        XCTAssertEqual(
            SettingsView.resetOnboardingErrorMessage(for: APIError.notFound(message: "Not found")),
            "This account can't be reset."
        )
        XCTAssertEqual(
            SettingsView.resetOnboardingErrorMessage(for: APIError.serverError(message: "boom")),
            "Couldn't reset. Try again."
        )
    }
}

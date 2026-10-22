import Foundation
import UIKit
import Combine

/// The voice onboarding (docs/onboarding-voice-handoff.md, sections 2 and
/// 6.1, reworked in THEDUMP-101): learn how sorting works, talk or type
/// about what you're juggling, say what the names you used mean, answer up
/// to two follow-up questions, approve the drafted categories, save them,
/// then make a first note and watch it get sorted. Or set the categories up
/// by hand from the first screen.
///
/// Progress is saved on the phone after every change, so a killed app comes
/// back at the same step and never asks someone to record again once their
/// words have been turned into text.
@MainActor
final class OnboardingV2ViewModel: ObservableObject {
    /// Screen 2's in-between states.
    enum RecordMode: Equatable {
        case idle
        case recording
        case typing
        case micDenied
    }

    /// A follow-up question's in-between states on screen 3 (3c).
    enum AnswerState: Equatable {
        case recording
        case transcribing
        case typing
        case transcribeFailed
    }

    @Published private(set) var progress: OnboardingProgress {
        didSet {
            // A late reply after leaving must not bring the progress back,
            // or the next launch would reopen the onboarding.
            guard !hasLeft else { return }
            store?.save(progress)
        }
    }

    @Published var recordMode: RecordMode = .idle {
        didSet { if recordMode != oldValue { recordNotice = nil } }
    }
    /// Shown on screen 2 when a recording came back empty.
    @Published private(set) var recordNotice: String?
    /// How many "Heard …" lines on 2b have appeared so far.
    @Published private(set) var heardLinesShown = 0
    /// How many "name → category" lines on 3b have appeared so far.
    @Published private(set) var buildingLinesShown = 0
    /// The draft 3b is revealing, before it becomes the cards on screen 4.
    @Published private(set) var buildingDraft: [OnboardingDraftCard]?
    @Published private(set) var isRunningStep = false
    @Published private(set) var answerStates: [Int: AnswerState] = [:]
    /// The names step's open box (2g), while it is being typed or recorded.
    @Published private(set) var namesNoteState: AnswerState?
    /// The card shown open on screen 4.
    @Published var openCardId: UUID?
    @Published private(set) var isFinishing = false
    @Published private(set) var finishError: String?
    @Published private(set) var isSavingFirstNote = false
    @Published private(set) var firstNoteError: String?
    @Published private(set) var isChangingCategory = false
    @Published private(set) var changeError: String?

    /// Most "Heard …" and "name → category" lines a loading screen shows.
    static let maxRevealedLines = 4
    /// The gap between revealed lines (decided in the handoff, 6.1 step 3).
    static let revealInterval: TimeInterval = 0.3
    /// A short beat after the last tick, so the finished screen is seen.
    static let settleInterval: TimeInterval = 0.6
    /// How often screen 6 asks whether the first note is sorted. Two
    /// seconds, not one, because the web app allows 60 requests a minute.
    static let firstNotePollInterval: TimeInterval = 2

    let client: OnboardingClient
    private let store: OnboardingProgressStore?
    private let recordingDirectory: URL
    private var draftTask: Task<[OnboardingDraftCard], Error>?
    private var answerTasks: [Int: Task<Void, Never>] = [:]
    private var namesNoteTask: Task<Void, Never>?
    private var isPollingFirstNote = false
    private var hasLeft = false

    init(
        client: OnboardingClient,
        store: OnboardingProgressStore?,
        recordingDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    ) {
        self.client = client
        self.store = store
        self.recordingDirectory = recordingDirectory
        self.progress = store?.load() ?? OnboardingProgress()
    }

    convenience init(uid: String) {
        self.init(client: .live, store: OnboardingProgressStore(uid: uid))
    }

    var step: OnboardingStep { progress.step }

    var rules: OnboardingCategoryRules {
        progress.config?.categoryRules ?? OnboardingCategoryRules()
    }

    var recordingLimits: OnboardingRecordingLimits {
        progress.config?.recording ?? OnboardingRecordingLimits()
    }

    var trySaying: [String] { progress.config?.trySaying ?? [] }

    var catchAllName: String? { progress.config?.catchAll?.name }

    // MARK: - Starting and resuming

    /// Called when the onboarding appears: fetches the copy and limits if
    /// they aren't saved yet, and picks up any step that was in flight when
    /// the app was closed.
    func resume() async {
        await loadConfigIfNeeded()
        switch progress.step {
        case .listening:
            await runListening()
        case .names:
            prepareNameRows()
            startInitialDraftIfNeeded()
        case .questions:
            startInitialDraftIfNeeded()
        case .building:
            await runBuilding()
        case .review:
            openCardId = openCardId ?? firstUnapprovedCardId()
        case .promise, .explainer, .record, .done, .first:
            break
        }
    }

    /// Fetches the config when there is none yet, or when the saved one has
    /// no catch-all (Finish can't save without it), so a failed or partial
    /// fetch is tried again on the next screen that needs it.
    func loadConfigIfNeeded() async {
        guard progress.config?.catchAll == nil else { return }
        if let config = try? await retrying({ try await self.client.config() }) {
            progress.config = config
        }
    }

    /// Screen 1's "Begin": first, how sorting works (1b).
    func begin() {
        progress.setupMode = .talk
        progress.step = .explainer
    }

    /// 1b's "Continue".
    func continueFromExplainer() {
        progress.step = .record
        recordMode = .idle
    }

    // MARK: - Setting up by hand (4m)

    var isManualSetup: Bool { progress.setupMode == .manual }

    /// Screen 1's "Set up my categories myself": straight to an empty
    /// review screen, where each category is added with 4c.
    func setUpMyself() {
        progress.setupMode = .manual
        progress.step = .review
        openCardId = nil
    }

    /// 4m's "Let the AI draft them": the talking path, keeping any
    /// categories already added (they come first on screen 4).
    func letAIDraft() {
        progress.setupMode = .talk
        progress.step = .explainer
    }

    // MARK: - Screen 2: what are you juggling

    func startTyping() { recordMode = .typing }
    func talkInstead() { recordMode = .idle }
    func showMicDenied() { recordMode = .micDenied }
    func recordingStarted() { recordMode = .recording }
    func recordingDiscarded() { recordMode = .idle }

    /// The ramble was recorded; it is kept on the phone until it has been
    /// turned into text, then deleted.
    func submitRecording(fileURL: URL) async {
        progress.pendingRecordingName = fileURL.lastPathComponent
        progress.transcriptSource = .voice
        progress.step = .listening
        recordMode = .idle
        await runListening()
    }

    func submitTyped(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        progress.transcript = trimmed
        progress.transcriptSource = .typed
        progress.step = .listening
        recordMode = .idle
        await runListening()
    }

    /// Under about 20 words the typing screen suggests saying a bit more;
    /// it never blocks Continue.
    static func wordCount(_ text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    // MARK: - Screen 2b: listening back

    var heardPhrases: [String] {
        Array((progress.extraction?.items ?? []).map(\.heardPhrase).prefix(Self.maxRevealedLines))
    }

    var isTranscribeDone: Bool { progress.transcript != nil }
    var isReadDone: Bool { progress.extraction != nil }
    /// The check's row ticks only once the "Heard …" lines have all
    /// appeared, so the two ticks never land at once.
    var isCheckDone: Bool {
        progress.gapCheck != nil && isReadDone && heardLinesShown >= heardPhrases.count
    }

    /// Runs whatever of transcribe, read and check hasn't finished yet, and
    /// starts the first draft in the background as soon as there is a
    /// transcript. Read and check run side by side; then on to screen 3,
    /// or straight to 3b when the check has no questions.
    func runListening() async {
        guard !isRunningStep else { return }
        isRunningStep = true
        progress.failure = nil
        let ready = await prepareTranscript()
        guard ready, let transcript = progress.transcript else {
            isRunningStep = false
            return
        }
        startInitialDraftIfNeeded()

        async let readOK = readIfNeeded(transcript: transcript)
        async let checkOK = checkIfNeeded(transcript: transcript)
        let (didRead, didCheck) = await (readOK, checkOK)
        guard didRead, didCheck else {
            isRunningStep = false
            return
        }
        try? await client.sleep(Self.settleInterval)
        isRunningStep = false
        await leaveListening()
    }

    private func prepareTranscript() async -> Bool {
        if progress.transcript != nil { return true }
        guard let name = progress.pendingRecordingName else {
            // Nothing was saved to work from: back to the recording screen.
            progress.step = .record
            return false
        }
        let file = recordingDirectory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: file.path) else {
            progress.pendingRecordingName = nil
            progress.step = .record
            return false
        }
        do {
            let sessionId = progress.sessionId
            let result = try await retrying {
                try await self.client.transcribe(file, .ramble, sessionId, [])
            }
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                // Silence: start over rather than draft from nothing.
                deleteRecording(named: name)
                progress.pendingRecordingName = nil
                progress.step = .record
                recordNotice = "We didn’t catch anything. Try again, or type instead."
                return false
            }
            progress.transcript = text
            progress.pendingRecordingName = nil
            deleteRecording(named: name)
            return true
        } catch {
            fail(.transcribe, error)
            return false
        }
    }

    private func readIfNeeded(transcript: String) async -> Bool {
        if progress.extraction == nil {
            do {
                let sessionId = progress.sessionId
                progress.extraction = try await retrying { try await self.client.read(transcript, sessionId) }
            } catch {
                fail(.read, error)
                return false
            }
        }
        while heardLinesShown < heardPhrases.count {
            try? await client.sleep(Self.revealInterval)
            heardLinesShown += 1
        }
        return true
    }

    private func checkIfNeeded(transcript: String) async -> Bool {
        guard progress.gapCheck == nil else { return true }
        do {
            let sessionId = progress.sessionId
            progress.gapCheck = try await retrying { try await self.client.check(transcript, sessionId) }
            return true
        } catch {
            fail(.check, error)
            return false
        }
    }

    /// On to the names step; the follow-up questions (if any) come after it.
    private func leaveListening() async {
        let questions = progress.gapCheck?.questions ?? []
        if questions.isEmpty {
            progress.followups = []
        } else if progress.followups.isEmpty {
            progress.followups = questions.prefix(2).map { OnboardingFollowup(question: $0.question) }
        }
        prepareNameRows()
        progress.step = .names
    }

    // MARK: - Screen 2h (or 2g): names only you'd know

    /// 2h lists the names heard; with fewer than two, 2g's open box shows.
    var listsNames: Bool { OnboardingRules.listsNames(progress.extraction) }

    var nameRows: [OnboardingNameRow] { progress.nameRows ?? [] }

    var namesNote: String { progress.namesNote ?? "" }

    private func prepareNameRows() {
        guard progress.nameRows == nil else { return }
        progress.nameRows = listsNames ? OnboardingRules.nameRows(from: progress.extraction) : []
    }

    func updateNameRow(_ id: UUID, name: String? = nil, meaning: String? = nil) {
        guard let index = progress.nameRows?.firstIndex(where: { $0.id == id }) else { return }
        if let name { progress.nameRows?[index].name = name }
        if let meaning { progress.nameRows?[index].meaning = meaning }
    }

    /// "Add a nickname or name we missed". Returns the new row's id so the
    /// screen can put the cursor in it.
    @discardableResult
    func addNameRow() -> UUID {
        let row = OnboardingNameRow(name: "", isAdded: true)
        progress.nameRows = (progress.nameRows ?? []) + [row]
        return row.id
    }

    func removeNameRow(_ id: UUID) {
        progress.nameRows?.removeAll { $0.id == id }
    }

    func updateNamesNote(_ text: String) {
        progress.namesNote = text
    }

    func startNamesRecording() { namesNoteState = .recording }
    func startTypingNames() { namesNoteState = .typing }
    func cancelNamesRecording() { namesNoteState = .typing }

    /// 2g's "Talk instead": what they say is added to the box, so they can
    /// read it back and fix a spelling before Continue.
    func submitNamesRecording(fileURL: URL) {
        namesNoteState = .transcribing
        let sessionId = progress.sessionId
        let names = knownNames
        namesNoteTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.retrying {
                    try await self.client.transcribe(fileURL, .answer, sessionId, names)
                }
                let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    self.namesNoteState = .transcribeFailed
                } else {
                    let current = self.namesNote.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.progress.namesNote = current.isEmpty ? text : "\(current)\n\(text)"
                    self.namesNoteState = .typing
                }
            } catch {
                self.namesNoteState = .transcribeFailed
            }
            try? FileManager.default.removeItem(at: fileURL)
            self.namesNoteTask = nil
        }
    }

    var isWaitingForNamesNote: Bool { namesNoteTask != nil }

    /// The names step's "Continue": waits for a spoken note still being
    /// turned into text, then on to the questions, or straight to 3b when
    /// there are none. Every row is optional.
    func continueFromNames() async {
        await namesNoteTask?.value
        namesNoteState = nil
        if progress.followups.isEmpty {
            progress.step = .building
            await runBuilding()
        } else {
            progress.step = .questions
        }
    }

    /// 2g's "Skip": nothing from the box is sent.
    func skipNames() async {
        namesNoteTask?.cancel()
        // A recording already on its way would otherwise land after the clear.
        await namesNoteTask?.value
        progress.namesNote = nil
        await continueFromNames()
    }

    // MARK: - Drafting

    /// Fires the first draft from the transcript alone, so it is usually
    /// ready by the time the follow-up questions are done.
    func startInitialDraftIfNeeded() {
        guard progress.initialDraft == nil, draftTask == nil, let transcript = progress.transcript else { return }
        let request = OnboardingDraftRequest(
            sessionId: progress.sessionId, transcript: transcript, answers: [], previousDraft: nil
        )
        let client = client
        let task = Task { () throws -> [OnboardingDraftCard] in
            do {
                return try await client.draft(request)
            } catch where Self.isRetryable(error) {
                return try await client.draft(request)
            }
        }
        draftTask = task
        Task { [weak self] in
            guard let cards = try? await task.value else { return }
            self?.progress.initialDraft = cards
        }
    }

    private func initialDraft() async throws -> [OnboardingDraftCard] {
        if let draft = progress.initialDraft { return draft }
        startInitialDraftIfNeeded()
        guard let task = draftTask else { throw APIError.unknownError }
        do {
            let draft = try await task.value
            progress.initialDraft = draft
            return draft
        } catch {
            draftTask = nil
            throw error
        }
    }

    // MARK: - Screen 3: follow-up questions

    var questionsHeadline: String { OnboardingRules.questionsHeadline(count: progress.followups.count) }

    var questionsBody: String { OnboardingRules.questionsBody(summary: progress.gapCheck?.summary ?? "") }

    /// The question waiting for an answer: the first one neither answered
    /// nor skipped.
    var activeQuestionIndex: Int? {
        progress.followups.firstIndex { $0.source == nil }
    }

    /// Names from the ramble, sent with spoken answers so they're spelled right.
    var knownNames: [String] {
        (progress.extraction?.names ?? []).map(\.name)
    }

    func startAnswerRecording(_ index: Int) { answerStates[index] = .recording }
    func startTypingAnswer(_ index: Int) { answerStates[index] = .typing }
    func cancelAnswerInput(_ index: Int) { answerStates[index] = nil }

    func submitTypedAnswer(_ index: Int, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard progress.followups.indices.contains(index), !trimmed.isEmpty else { return }
        progress.followups[index].answer = trimmed
        progress.followups[index].source = .typed
        answerStates[index] = nil
    }

    func skipQuestion(_ index: Int) {
        guard progress.followups.indices.contains(index) else { return }
        progress.followups[index].answer = nil
        progress.followups[index].source = .skipped
        answerStates[index] = nil
    }

    /// A spoken answer: shown as "Listening back…" until its text returns.
    /// "Build my categories" waits for it.
    func submitAnswerRecording(_ index: Int, fileURL: URL) {
        guard progress.followups.indices.contains(index) else { return }
        answerStates[index] = .transcribing
        let sessionId = progress.sessionId
        let names = knownNames
        answerTasks[index] = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.retrying {
                    try await self.client.transcribe(fileURL, .answer, sessionId, names)
                }
                let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    self.answerStates[index] = .transcribeFailed
                } else {
                    self.progress.followups[index].answer = text
                    self.progress.followups[index].source = .voice
                    self.answerStates[index] = nil
                }
            } catch {
                self.answerStates[index] = .transcribeFailed
            }
            try? FileManager.default.removeItem(at: fileURL)
            self.answerTasks[index] = nil
        }
    }

    var isWaitingForAnswers: Bool { !answerTasks.isEmpty }

    /// "Build my categories": waits for answers still being turned into
    /// text, counts any unanswered question as skipped, then drafts.
    func buildCategories() async {
        for task in answerTasks.values {
            await task.value
        }
        for index in progress.followups.indices where progress.followups[index].source == nil {
            progress.followups[index].source = .skipped
        }
        answerStates = [:]
        progress.step = .building
        await runBuilding()
    }

    // MARK: - Screen 3b: building categories

    /// The "name → category" lines on 3b.
    var buildingLines: [String] {
        (buildingDraft ?? []).compactMap { card in
            let names = card.names.prefix(2)
            guard !names.isEmpty else { return nil }
            return "\(names.joined(separator: ", ")) → \(card.name)"
        }
        .prefix(Self.maxRevealedLines)
        .map { $0 }
    }

    var isDraftDone: Bool { buildingDraft != nil }
    var isBuildingDone: Bool { isDraftDone && buildingLinesShown >= buildingLines.count }

    /// Revises the first draft with the answers when any were given;
    /// otherwise the first draft is used as it is.
    func runBuilding() async {
        guard !isRunningStep else { return }
        isRunningStep = true
        progress.failure = nil
        buildingDraft = nil
        buildingLinesShown = 0
        defer { isRunningStep = false }
        do {
            let draft = try await finalDraft()
            buildingDraft = draft
            while buildingLinesShown < buildingLines.count {
                try? await client.sleep(Self.revealInterval)
                buildingLinesShown += 1
            }
            try? await client.sleep(Self.settleInterval)
            // Categories added by hand before choosing the AI are kept (4m).
            progress.cards = OnboardingRules.mergedCards(kept: progress.cards, draft: draft, hardMax: rules.hardMax)
            progress.step = .review
            openCardId = firstUnapprovedCardId()
        } catch {
            fail(.draft, error)
        }
    }

    /// The answers that go to revise mode: the names step's (one, at most)
    /// and the follow-up questions'.
    var draftAnswers: [OnboardingAnswer] {
        let names = OnboardingRules.namesAnswer(rows: nameRows, note: progress.namesNote)
        return (names.map { [$0] } ?? []) + OnboardingRules.answers(from: progress.followups)
    }

    private func finalDraft() async throws -> [OnboardingDraftCard] {
        let initial = try await initialDraft()
        let answers = draftAnswers
        guard !answers.isEmpty, let transcript = progress.transcript else { return initial }
        let request = OnboardingDraftRequest(
            sessionId: progress.sessionId, transcript: transcript, answers: answers, previousDraft: initial
        )
        return try await retrying { try await self.client.draft(request) }
    }

    // MARK: - Failures

    /// Re-runs only the step that failed, from what was saved.
    func retryFailedStep() async {
        switch progress.step {
        case .listening:
            await runListening()
        case .building:
            await runBuilding()
        default:
            progress.failure = nil
        }
    }

    private func fail(_ task: OnboardingTask, _ error: Error) {
#if DEBUG
        print("[Onboarding] \(task.rawValue) failed: \(error)")
#endif
        progress.failure = OnboardingFailure(task: task, message: Self.message(for: error))
    }

    // MARK: - Calls

    /// Every AI call is retried once on its own before the screen shows a
    /// failure. Requests the server refused (bad input, sign-in, a clash)
    /// are not retried, because they would fail the same way.
    func retrying<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch where Self.isRetryable(error) {
            return try await operation()
        }
    }

    nonisolated static func isRetryable(_ error: Error) -> Bool {
        // A cancelled request means the screen went away; don't start it again.
        if error is CancellationError || Task.isCancelled { return false }
        guard let apiError = error as? APIError else { return true }
        switch apiError {
        case .networkError(let underlying):
            if underlying is CancellationError { return false }
            return (underlying as? URLError)?.code != .cancelled
        case .serverError, .upstreamFailed, .decodingFailed, .unknownError:
            return true
        case .httpError(let status, _):
            return status >= 500
        default:
            return false
        }
    }

    static func message(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .conflict(let message), .notFound(let message), .badRequest(let message):
                return message
            case .httpError(_, let message):
                return message
            default:
                break
            }
        }
        return "Something went wrong on our side. Try again."
    }

    func deleteRecording(named name: String) {
        try? FileManager.default.removeItem(at: recordingDirectory.appendingPathComponent(name))
    }

    func firstUnapprovedCardId() -> UUID? {
        progress.cards.first { !$0.approved }?.id
    }

    // MARK: - Leaving

    /// Leaving onboarding for good (Go to my Dump, the capture bar on 6b,
    /// or the Claude link): the saved progress is no longer needed.
    func leave() {
        hasLeft = true
        store?.clear()
    }
}

// MARK: - Screens 4 and 4b: approving and editing cards

extension OnboardingV2ViewModel {
    enum ChipList {
        case names
        case examples
    }

    var approvedCount: Int { progress.cards.filter(\.approved).count }

    var canFinish: Bool { OnboardingRules.canFinish(cards: progress.cards, rules: rules) }

    /// Remove is hidden once only the minimum number of cards is left. Set up
    /// by hand, the list starts empty, so the minimum only blocks Finish and a
    /// card added by mistake can always go.
    var canRemoveCards: Bool { isManualSetup || progress.cards.count > rules.min }

    var canAddCards: Bool { progress.cards.count < rules.hardMax }

    /// "Finish", or what is still in the way: "Finish · 3 left".
    var finishLabel: String {
        let missing = rules.min - progress.cards.count
        if missing > 0 {
            return "Finish · add \(missing) more"
        }
        let left = progress.cards.count - approvedCount
        return left > 0 ? "Finish · \(left) left" : "Finish"
    }

    func openCard(_ id: UUID) {
        openCardId = id
    }

    /// "Looks right". A card with no names can't be approved.
    func approveCard(_ id: UUID) {
        guard let index = progress.cards.firstIndex(where: { $0.id == id }),
              progress.cards[index].canApprove else { return }
        progress.cards[index].approved = true
        openCardId = firstUnapprovedCardId()
    }

    /// "+ Add" on an open card.
    func addChip(_ text: String, to list: ChipList, cardId: UUID) {
        guard let index = progress.cards.firstIndex(where: { $0.id == cardId }) else { return }
        switch list {
        case .names:
            progress.cards[index].names = OnboardingRules.cleanedChips(progress.cards[index].names + [text])
        case .examples:
            progress.cards[index].examples = OnboardingRules.cleanedChips(progress.cards[index].examples + [text])
        }
    }

    /// What blocks these edits; empty when they can be saved. `cardId` is
    /// nil for a new card.
    func editErrors(cardId: UUID?, name: String, names: [String]) -> OnboardingCardEditErrors {
        OnboardingRules.editErrors(
            name: name,
            names: names,
            others: progress.cards.filter { $0.id != cardId }.map(\.name),
            catchAllName: catchAllName,
            maxLength: rules.nameMaxChars
        )
    }

    /// 4b's Save: updates the card (or adds it when `cardId` is nil) and
    /// marks it approved. Returns what to show under the fields instead when
    /// the edits can't be saved, or nil once saved.
    @discardableResult
    func saveCard(
        cardId: UUID?,
        name: String,
        description: String,
        names: [String],
        examples: [String]
    ) -> OnboardingCardEditErrors? {
        let errors = editErrors(cardId: cardId, name: name, names: names)
        guard errors.isEmpty else { return errors }
        let card = OnboardingCard(
            id: cardId ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            examples: OnboardingRules.cleanedChips(examples),
            names: OnboardingRules.cleanedChips(names),
            approved: true
        )
        if let index = progress.cards.firstIndex(where: { $0.id == card.id }) {
            progress.cards[index] = card
        } else {
            guard canAddCards else {
                return OnboardingCardEditErrors(name: "You can have up to \(rules.hardMax) categories.")
            }
            progress.cards.append(card)
        }
        finishError = nil
        openCardId = firstUnapprovedCardId()
        return nil
    }

    func removeCard(_ id: UUID) {
        guard canRemoveCards else { return }
        progress.cards.removeAll { $0.id == id }
        if openCardId == id {
            openCardId = firstUnapprovedCardId()
        }
    }

    // MARK: Finish

    /// Saves every card and "Everything else" in one request. A name clash
    /// (409) is shown on the card it is about, which then needs approving
    /// again.
    func finish() async {
        guard canFinish, !isFinishing else { return }
        isFinishing = true
        finishError = nil
        defer { isFinishing = false }

        await loadConfigIfNeeded()
        guard let catchAll = progress.config?.catchAll else {
            // Finish stays enabled, and tapping it fetches the config again.
            finishError = Self.message(for: APIError.unknownError)
            return
        }
        do {
            let saved = try await saveAll(catchAll: catchAll)
            progress.savedCategories = Self.savedCategories(saved, cards: progress.cards, catchAll: catchAll)
            progress.step = .done
        } catch APIError.conflict(let message) {
            showClash(message)
        } catch {
            finishError = Self.message(for: error)
        }
    }

    /// Sending the same save twice is safe, so it is retried like the AI
    /// calls: the server updates a category whose name matches exactly
    /// (`plan_category_saves`) instead of refusing it, so a retry after a
    /// lost reply finds the first attempt's categories and updates them.
    private func saveAll(catchAll: OnboardingCatchAll) async throws -> [CategoryResponse] {
        let payload = OnboardingRules.finishPayload(cards: progress.cards, catchAll: catchAll)
        do {
            return try await retrying { try await self.client.saveCategories(payload) }
        } catch APIError.conflict(let message)
            where OnboardingRules.clashingName(in: message).map(OnboardingRules.nameKey) == OnboardingRules.nameKey(catchAll.name) {
            // "Everything else" was archived on this account: save the
            // cards on their own, then bring the old catch-all back.
            let cardsOnly = OnboardingRules.finishPayload(cards: progress.cards, catchAll: nil)
            var saved = try await retrying { try await self.client.saveCategories(cardsOnly) }
            if let restored = await restoreCatchAll(named: catchAll.name) {
                saved.append(restored)
            }
            return saved
        }
    }

    /// Brings an archived catch-all back. Best effort: the cards are saved
    /// by now, so a failure here still finishes onboarding rather than
    /// leaving the person stuck on screen 4; their notes then go to the
    /// other categories until they restore it in Settings.
    private func restoreCatchAll(named name: String) async -> CategoryResponse? {
        let key = OnboardingRules.nameKey(name)
        do {
            let existing = try await retrying { try await self.client.fetchCategories() }
            guard let old = existing.first(where: { OnboardingRules.nameKey($0.name) == key }) else { return nil }
            try await retrying { try await self.client.restoreCategory(old.categoryId) }
            return old
        } catch {
#if DEBUG
            print("[Onboarding] Restoring the catch-all failed: \(error)")
#endif
            return nil
        }
    }

    private func showClash(_ message: String) {
        let key = OnboardingRules.clashingName(in: message).map(OnboardingRules.nameKey)
        guard let key, let index = progress.cards.firstIndex(where: { OnboardingRules.nameKey($0.name) == key }) else {
            finishError = message
            return
        }
        progress.cards[index].errorMessage = message
        progress.cards[index].approved = false
        openCardId = progress.cards[index].id
    }

    /// The saved categories in the order of the cards, catch-all last.
    static func savedCategories(
        _ saved: [CategoryResponse],
        cards: [OnboardingCard],
        catchAll: OnboardingCatchAll
    ) -> [OnboardingSavedCategory] {
        let catchAllKey = OnboardingRules.nameKey(catchAll.name)
        let order = cards.map { OnboardingRules.nameKey($0.name) } + [catchAllKey]
        return saved
            .map { response in
                OnboardingSavedCategory(
                    id: response.categoryId,
                    name: response.name,
                    keywordCount: response.keywords.count,
                    isCatchAll: OnboardingRules.nameKey(response.name) == catchAllKey
                )
            }
            .sorted { lhs, rhs in
                let left = order.firstIndex(of: OnboardingRules.nameKey(lhs.name)) ?? order.count
                let right = order.firstIndex(of: OnboardingRules.nameKey(rhs.name)) ?? order.count
                return left < right
            }
    }
}

// MARK: - Screens 5 and 6: the first note

extension OnboardingV2ViewModel {
    /// Screen 5's stats: every saved category, the catch-all included.
    var savedCategoryCount: Int { progress.savedCategories.count }

    /// "Names it knows": the keywords saved across the categories.
    var savedNameCount: Int { progress.savedCategories.reduce(0) { $0 + $1.keywordCount } }

    var savedCategoryLine: String {
        progress.savedCategories.map(\.name).joined(separator: " · ")
    }

    func submitFirstText(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await saveFirstNote(kind: .text, localText: trimmed) {
            try await self.client.uploadText(trimmed)
        }
    }

    /// A spoken first note is turned into text and saved as a typed note;
    /// the recording is deleted either way (D-020).
    func submitFirstRecording(fileURL: URL) async {
        guard !isSavingFirstNote else { return }
        isSavingFirstNote = true
        firstNoteError = nil
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let sessionId = progress.sessionId
        let transcript: String
        do {
            let result = try await retrying {
                try await self.client.transcribe(fileURL, .capture, sessionId, [])
            }
            transcript = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            isSavingFirstNote = false
            firstNoteError = "That didn't go through. Try again, or type it instead."
            return
        }
        isSavingFirstNote = false
        guard !transcript.isEmpty else {
            firstNoteError = "We didn't catch anything. Try again, or type it instead."
            return
        }
        await saveFirstNote(kind: .voice, localText: transcript) {
            try await self.client.uploadText(transcript)
        }
    }

    func submitFirstPhoto(_ image: UIImage) async {
        await saveFirstNote(kind: .photo, localText: "Photo") {
            try await self.client.uploadPhoto(image)
        }
    }

    func submitFirstFile(_ url: URL) async {
        let name = url.lastPathComponent
        if let notice = CaptureFileTypes.skippedNotice(forFilenames: [name]) {
            firstNoteError = notice.message
            return
        }
        await saveFirstNote(kind: .file, localText: name) {
            try await self.client.uploadFile(url)
        }
    }

    func clearFirstNoteError() {
        firstNoteError = nil
    }

    /// Uploads are not retried on their own: a lost reply after a
    /// successful upload would otherwise save the note twice.
    private func saveFirstNote(
        kind: OnboardingFirstNote.Kind,
        localText: String,
        upload: () async throws -> String
    ) async {
        guard !isSavingFirstNote else { return }
        isSavingFirstNote = true
        firstNoteError = nil
        defer { isSavingFirstNote = false }
        do {
            let fileUuid = try await upload()
            progress.firstNote = OnboardingFirstNote(fileUuid: fileUuid, kind: kind, localText: localText)
            progress.step = .first
        } catch {
            firstNoteError = "That didn't go through. Check your connection and try again."
        }
    }

    /// Asks every two seconds until the first note is sorted or fails.
    /// Runs while screen 6 is showing (cancelled when it goes away).
    func pollFirstNote() async {
        guard !isPollingFirstNote else { return }
        isPollingFirstNote = true
        defer { isPollingFirstNote = false }
        while progress.step == .first, let note = progress.firstNote, note.status == .processing {
            do {
                try await client.sleep(Self.firstNotePollInterval)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            if let entry = try? await client.fileStatus(note.fileUuid) {
                applyFirstNoteStatus(entry)
            }
        }
    }

    func applyFirstNoteStatus(_ entry: FileStatusEntry) {
        guard var note = progress.firstNote, note.fileUuid == entry.fileUuid, note.status == .processing else { return }
        switch NoteWireStatus(rawValue: entry.status) {
        case .transcribed:
            if let preview = entry.noteContentPreview, !preview.isEmpty {
                note.preview = preview
            }
        case .completed:
            note.status = .sorted
            note.organizedNoteId = entry.organizedNoteId
            note.categoryId = entry.categoryId
            note.categoryName = entry.categoryName
            note.decisionReason = entry.decisionReason
            if let preview = entry.noteContentPreview, !preview.isEmpty {
                note.preview = preview
            }
        case .failed:
            note.status = .failed
        case .processing, nil:
            return
        }
        progress.firstNote = note
    }

    /// The category row the first note landed in (lit on 6b).
    func isFirstNoteCategory(_ category: OnboardingSavedCategory) -> Bool {
        guard let note = progress.firstNote, note.status == .sorted else { return false }
        if let categoryId = note.categoryId {
            return categoryId == category.id
        }
        return OnboardingRules.nameKey(note.categoryName ?? "") == OnboardingRules.nameKey(category.name)
    }

    /// "Change": moves the note through `/api/edit_note` and hides the
    /// sorter's reason, which no longer matches.
    func changeFirstNoteCategory(to category: OnboardingSavedCategory) async {
        guard let note = progress.firstNote, let noteId = note.organizedNoteId, !isChangingCategory else { return }
        guard !isFirstNoteCategory(category) else { return }
        isChangingCategory = true
        changeError = nil
        defer { isChangingCategory = false }
        do {
            try await retrying { try await self.client.moveNote(noteId, category.id) }
            progress.firstNote?.categoryId = category.id
            progress.firstNote?.categoryName = category.name
            progress.firstNote?.reasonHidden = true
        } catch {
            changeError = "Couldn't move it. Try again."
        }
    }
}

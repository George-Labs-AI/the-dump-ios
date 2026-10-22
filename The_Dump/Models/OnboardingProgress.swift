import Foundation

// What the phone remembers about one person's onboarding, so a killed app
// comes back at the step it left (there is no server session; THEDUMP-39
// may add one). Saved as JSON in the App Group defaults, one entry per
// Firebase user, by `OnboardingProgressStore`.

/// The screens, in order. Each case is one screen of the Paper design;
/// in-between states (recording, typing, a failed step) live inside them.
/// 1b, 2g, 2h and 4m are on the Paper page "Rework after first test
/// (decided)" (THEDUMP-101).
enum OnboardingStep: String, Codable, CaseIterable, Comparable {
    case promise      // 1
    case explainer    // 1b
    case record       // 2, 2c, 2d, 2e
    case listening    // 2b, 2f
    case names        // 2h, or 2g when fewer than two names were heard
    case questions    // 3, 3c
    case building     // 3b
    case review       // 4, 4b
    case done         // 5
    case first        // 6a, 6b

    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.order < rhs.order
    }

    /// From screen 5 on, the categories are saved on the account.
    var isAfterFinish: Bool { self >= .done }
}

/// One AI step on a loading screen. Rows on 2b and 3b tick when the
/// matching step finishes, and a failure names the step to re-run.
enum OnboardingTask: String, Codable, Equatable {
    case transcribe
    case read
    case check
    case draft
    case finish
}

struct OnboardingFailure: Codable, Equatable {
    let task: OnboardingTask
    let message: String
}

/// A follow-up question on screen 3 and what happened to it.
struct OnboardingFollowup: Codable, Equatable {
    enum Source: String, Codable {
        case voice
        case typed
        case skipped
    }

    let question: String
    var answer: String?
    var source: Source?

    var isAnswered: Bool {
        guard source == .voice || source == .typed else { return false }
        return !(answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// A row on the names step (2h): a name heard in the ramble, or one the
/// person added, and what it means. A heard name starts with the AI's guess
/// at what it is, so most rows only need a glance.
struct OnboardingNameRow: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var meaning: String
    /// Added with "Add a nickname or name we missed", rather than heard.
    var isAdded: Bool

    init(id: UUID = UUID(), name: String, meaning: String = "", isAdded: Bool = false) {
        self.id = id
        self.name = name
        self.meaning = meaning
        self.isAdded = isAdded
    }
}

/// The words and answers a draft was made from.
struct OnboardingDraftInputs: Codable, Equatable {
    let transcript: String
    let answers: [OnboardingAnswer]
}

/// Talking it through (the AI drafts the categories), or setting them up
/// by hand from the first screen (4m).
enum OnboardingSetupMode: String, Codable, Equatable {
    case talk
    case manual
}

/// One category card on screen 4, editable on 4b. Nothing is saved to the
/// account until Finish.
struct OnboardingCard: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var description: String
    var examples: [String]
    var names: [String]
    var approved: Bool
    /// Why Finish refused this card (a name clash), shown on the card until
    /// it is edited.
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        examples: [String] = [],
        names: [String] = [],
        approved: Bool = false,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.examples = examples
        self.names = names
        self.approved = approved
        self.errorMessage = errorMessage
    }

    init(draft: OnboardingDraftCard) {
        self.init(
            name: draft.name,
            description: draft.description,
            examples: OnboardingRules.cleanedChips(draft.examples),
            names: OnboardingRules.cleanedChips(draft.names)
        )
    }

    var draft: OnboardingDraftCard {
        OnboardingDraftCard(name: name, description: description, examples: examples, names: names)
    }

    /// A card with no names cannot be approved.
    var canApprove: Bool { !names.isEmpty }
}

/// A category as saved at Finish, kept for screens 5 and 6 (the counts, the
/// "Change" picker, and lighting up the row the first note lands in).
struct OnboardingSavedCategory: Codable, Equatable, Identifiable {
    let id: Int
    let name: String
    let keywordCount: Int
    let isCatchAll: Bool
}

/// The first note (screen 6) and where it got to.
struct OnboardingFirstNote: Codable, Equatable {
    enum Kind: String, Codable {
        case text
        case voice
        case photo
        case file
    }

    enum Status: String, Codable {
        case processing
        case sorted
        case failed
    }

    let fileUuid: String
    let kind: Kind
    /// What to show before the server has read it: the typed text or the
    /// transcript, or the file name for a photo or file.
    let localText: String
    var status: Status = .processing
    /// The text the server read (for a photo or file, the text read from it).
    var preview: String?
    var organizedNoteId: String?
    var categoryId: Int?
    var categoryName: String?
    var decisionReason: String?
    /// Set once the person picks another category with "Change"; the reason
    /// explained the sorter's choice, so it is hidden from then on.
    var reasonHidden: Bool = false

    /// The note's text for the card: what the server read when it has it,
    /// otherwise what was typed or said.
    var displayText: String {
        let read = (preview ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return read.isEmpty ? localText : read
    }

    /// The reason line under the note, or nil when it should not show.
    var visibleReason: String? {
        guard !reasonHidden else { return nil }
        let reason = (decisionReason ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return reason.isEmpty ? nil : reason
    }
}

struct OnboardingProgress: Codable, Equatable {
    var step: OnboardingStep = .promise
    /// Made up on the phone and sent with every AI call; the backend only
    /// logs it, so it never needs to exist on the server.
    var sessionId: String = UUID().uuidString.lowercased()
    var config: OnboardingConfig?

    /// The file name (in Documents) of a recording that hasn't been turned
    /// into text yet. Deleted as soon as the transcript is saved.
    var pendingRecordingName: String?
    var transcript: String?
    var transcriptSource: OnboardingFollowup.Source?
    var extraction: OnboardingReadResult?
    var gapCheck: OnboardingCheckResult?
    var followups: [OnboardingFollowup] = []
    /// The names step's rows (2h), made from the names heard when the step
    /// is first shown. Optional, like the fields below, so progress saved
    /// by an earlier build still loads.
    var nameRows: [OnboardingNameRow]?
    /// What was typed or said in the names step's open box (2g).
    var namesNote: String?
    var setupMode: OnboardingSetupMode?
    /// The first draft, from the transcript alone.
    var initialDraft: [OnboardingDraftCard]?
    var cards: [OnboardingCard] = []
    /// What the cards were drafted from. Someone who goes back and comes
    /// forward again without changing any of it returns to the same cards
    /// without drafting again.
    var draftedFrom: OnboardingDraftInputs?
    var failure: OnboardingFailure?

    var savedCategories: [OnboardingSavedCategory] = []
    var firstNote: OnboardingFirstNote?
}

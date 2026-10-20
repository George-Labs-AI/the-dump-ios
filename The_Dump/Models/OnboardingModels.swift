import Foundation

// Wire types for the backend's onboarding routes (`/api/onboarding/*`,
// The_Dump_Backend/app/onboarding/routes.py) and the progress the phone keeps
// while someone is part-way through onboarding. Foundation only, so the
// decoding and the payload rules can be unit-tested.
//
// Every list decodes as empty when the key is missing, so a server that
// drops a field never fails the whole step.

// MARK: - GET /api/onboarding/config

struct OnboardingConfig: Codable, Equatable {
    let flowVersion: String?
    let trySaying: [String]
    let recording: OnboardingRecordingLimits
    let categoryRules: OnboardingCategoryRules
    let catchAll: OnboardingCatchAll?

    init(
        flowVersion: String? = nil,
        trySaying: [String] = [],
        recording: OnboardingRecordingLimits = OnboardingRecordingLimits(),
        categoryRules: OnboardingCategoryRules = OnboardingCategoryRules(),
        catchAll: OnboardingCatchAll? = nil
    ) {
        self.flowVersion = flowVersion
        self.trySaying = trySaying
        self.recording = recording
        self.categoryRules = categoryRules
        self.catchAll = catchAll
    }

    enum CodingKeys: String, CodingKey {
        case flowVersion = "flow_version"
        case trySaying = "try_saying"
        case recording
        case categoryRules = "category_rules"
        case catchAll = "catch_all"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        flowVersion = try c.decodeIfPresent(String.self, forKey: .flowVersion)
        trySaying = try c.decodeIfPresent([String].self, forKey: .trySaying) ?? []
        recording = try c.decodeIfPresent(OnboardingRecordingLimits.self, forKey: .recording) ?? OnboardingRecordingLimits()
        categoryRules = try c.decodeIfPresent(OnboardingCategoryRules.self, forKey: .categoryRules) ?? OnboardingCategoryRules()
        catchAll = try c.decodeIfPresent(OnboardingCatchAll.self, forKey: .catchAll)
    }
}

/// The recording rules (D-021): a "1 minute left" note at 9:00 and an
/// automatic stop at 10:00. The defaults are used when the server leaves a
/// value out.
struct OnboardingRecordingLimits: Codable, Equatable {
    var warnAtSeconds: Double = 540
    var hardStopSeconds: Double = 600

    init(warnAtSeconds: Double = 540, hardStopSeconds: Double = 600) {
        self.warnAtSeconds = warnAtSeconds
        self.hardStopSeconds = hardStopSeconds
    }

    enum CodingKeys: String, CodingKey {
        case warnAtSeconds = "warn_at_s"
        case hardStopSeconds = "hard_stop_s"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        warnAtSeconds = try c.decodeIfPresent(Double.self, forKey: .warnAtSeconds) ?? 540
        hardStopSeconds = try c.decodeIfPresent(Double.self, forKey: .hardStopSeconds) ?? 600
    }
}

/// How many cards screen 4 allows and how long a name may be.
struct OnboardingCategoryRules: Codable, Equatable {
    var min: Int = 3
    var hardMax: Int = 15
    var nameMaxChars: Int = 30

    init(min: Int = 3, hardMax: Int = 15, nameMaxChars: Int = 30) {
        self.min = min
        self.hardMax = hardMax
        self.nameMaxChars = nameMaxChars
    }

    enum CodingKeys: String, CodingKey {
        case min
        case hardMax = "hard_max"
        case nameMaxChars = "name_max_chars"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        min = try c.decodeIfPresent(Int.self, forKey: .min) ?? 3
        hardMax = try c.decodeIfPresent(Int.self, forKey: .hardMax) ?? 15
        nameMaxChars = try c.decodeIfPresent(Int.self, forKey: .nameMaxChars) ?? 30
    }
}

/// "Everything else": saved as a real category at Finish (D-023).
struct OnboardingCatchAll: Codable, Equatable {
    let name: String
    let description: String
}

// MARK: - POST /api/onboarding/transcribe

enum OnboardingTranscribeKind: String, Codable {
    /// What they're juggling (screen 2).
    case ramble
    /// A spoken answer to a follow-up question (screen 3).
    case answer
    /// A spoken first note (screen 5), saved afterwards as a typed note.
    case capture
}

struct OnboardingTranscription: Codable, Equatable {
    let text: String
    let durationSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case text
        case durationSeconds = "duration_s"
    }
}

// MARK: - POST /api/onboarding/read

/// The "Heard …" lines on screen 2b, and the names that help transcribe
/// later answers.
struct OnboardingReadResult: Codable, Equatable {
    let items: [Item]
    let names: [Name]

    struct Item: Codable, Equatable {
        let label: String
        let heardPhrase: String

        enum CodingKeys: String, CodingKey {
            case label
            case heardPhrase = "heard_phrase"
        }
    }

    struct Name: Codable, Equatable {
        let name: String
        let kind: String?
        let context: String?
    }

    init(items: [Item] = [], names: [Name] = []) {
        self.items = items
        self.names = names
    }

    enum CodingKeys: String, CodingKey {
        case items
        case names
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decodeIfPresent([Item].self, forKey: .items) ?? []
        names = try c.decodeIfPresent([Name].self, forKey: .names) ?? []
    }
}

// MARK: - POST /api/onboarding/check

/// The completeness check (D-022): the "You covered …" line and up to two
/// follow-up questions. No questions means screen 3 is skipped.
struct OnboardingCheckResult: Codable, Equatable {
    let summary: String
    let assessment: String?
    let questions: [Question]

    struct Question: Codable, Equatable {
        let question: String
        let why: String?
    }

    init(summary: String = "", assessment: String? = nil, questions: [Question] = []) {
        self.summary = summary
        self.assessment = assessment
        self.questions = questions
    }

    enum CodingKeys: String, CodingKey {
        case summary
        case assessment
        case questions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        assessment = try c.decodeIfPresent(String.self, forKey: .assessment)
        questions = try c.decodeIfPresent([Question].self, forKey: .questions) ?? []
    }
}

// MARK: - POST /api/onboarding/draft

/// One drafted category, as the backend sends it and as revise mode takes it
/// back in `previous_draft`.
struct OnboardingDraftCard: Codable, Equatable {
    let name: String
    let description: String
    /// "What you'll dump here".
    let examples: [String]
    /// "Names that mean this", saved as the category's keywords.
    let names: [String]

    init(name: String, description: String = "", examples: [String] = [], names: [String] = []) {
        self.name = name
        self.description = description
        self.examples = examples
        self.names = names
    }

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case examples
        case names
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        examples = try c.decodeIfPresent([String].self, forKey: .examples) ?? []
        names = try c.decodeIfPresent([String].self, forKey: .names) ?? []
    }
}

struct OnboardingDraftResponse: Codable, Equatable {
    let categories: [OnboardingDraftCard]

    enum CodingKeys: String, CodingKey {
        case categories
    }

    init(categories: [OnboardingDraftCard]) {
        self.categories = categories
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categories = try c.decodeIfPresent([OnboardingDraftCard].self, forKey: .categories) ?? []
    }
}

/// An answer sent to revise mode.
struct OnboardingAnswer: Codable, Equatable {
    let question: String
    let answer: String
}

struct OnboardingDraftRequest: Encodable, Equatable {
    let sessionId: String
    let transcript: String
    let answers: [OnboardingAnswer]
    /// Set only in revise mode.
    let previousDraft: [OnboardingDraftCard]?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case transcript
        case answers
        case previousDraft = "previous_draft"
    }
}

/// The body of `/read` and `/check`.
struct OnboardingTranscriptRequest: Encodable, Equatable {
    let sessionId: String
    let transcript: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case transcript
    }
}

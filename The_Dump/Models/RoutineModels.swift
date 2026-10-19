import Foundation

// Models for the Routines API served by the web server. Only the fields the
// UI reads are declared — Decodable ignores unknown keys, and `scope` is
// free-form JSON on the server so it is deliberately left out.

// MARK: - Responses

// GET /api/routines
struct RoutinesListResponse: Decodable {
    let routines: [RoutineSummary]
}

// GET /api/routines/<slug>  (routine + document metadata, no bodies)
struct RoutineDetailResponse: Decodable {
    let routineID: String
    let slug: String
    let name: String
    let description: String?
    let enabled: Bool
    let updatedAt: String?
    let status: RoutineStatus?
    let documents: [RoutineDocumentMeta]

    enum CodingKeys: String, CodingKey {
        case routineID = "routine_id"
        case slug
        case name
        case description
        case enabled
        case updatedAt = "updated_at"
        case status
        case documents
    }
}

// GET /api/routines/<slug>/asks
struct RoutineAsksResponse: Decodable {
    let asks: [RoutineAsk]
    let count: Int?
}

// POST /api/routines/<slug>/asks/<ask_id>/answer  (200 and 409 share this shape)
struct RoutineAnswerResponse: Decodable {
    let ask: RoutineAsk
    let error: String?
    let noop: Bool?
}

// GET /api/routines/scope-options  (the user's active categories and sub-categories)
struct RoutineScopeOptionsResponse: Decodable, Equatable {
    let categories: [RoutineScopeCategory]
    let subcategories: [RoutineScopeSubcategory]

    func subcategories(of categoryID: Int) -> [RoutineScopeSubcategory] {
        subcategories.filter { $0.categoryID == categoryID }
    }
}

// POST /api/routines/preview  (how many notes a scope matches, plus up to 12 recent ones)
struct RoutinePreviewResponse: Decodable, Equatable {
    let count: Int
    let notes: [RoutinePreviewNote]
}

// POST /api/routines  (201 when created, 200 when a retry finds the saved routine)
struct RoutineCreateResponse: Decodable {
    let routine: RoutineSummary
    let created: Bool?
    let setupURL: String?

    enum CodingKeys: String, CodingKey {
        case routine
        case created
        case setupURL = "setup_url"
    }
}

// MARK: - Requests

struct RoutineAnswerRequest: Encodable {
    let choice: String
    let text: String?
    let revision: Int
}

struct RoutinePreviewRequest: Encodable {
    let scope: RoutineScope
}

/// The server accepts exactly these four keys and rejects any other.
/// `requestID` lets a retry after a lost response find the routine the
/// first attempt saved instead of making a second one.
struct RoutineCreateRequest: Encodable, Equatable {
    let name: String
    let description: String
    let scope: RoutineScope
    let requestID: String

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case scope
        case requestID = "request_id"
    }
}

// PATCH /api/routines/<slug>
struct RoutinePauseRequest: Encodable {
    let paused: Bool
}

/// Which notes a routine reads. All notes is sent on its own; otherwise the
/// chosen categories and sub-categories are sent together, and the server
/// rejects a body that mixes the two or chooses nothing.
enum RoutineScope: Encodable, Equatable, Hashable {
    case allNotes
    case selected(categoryIDs: [Int], subCategoryIDs: [Int])

    private enum CodingKeys: String, CodingKey {
        case allNotes = "all_notes"
        case categoryIDs = "category_ids"
        case subCategoryIDs = "sub_category_ids"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .allNotes:
            try container.encode(true, forKey: .allNotes)
        case let .selected(categoryIDs, subCategoryIDs):
            try container.encode(categoryIDs, forKey: .categoryIDs)
            try container.encode(subCategoryIDs, forKey: .subCategoryIDs)
        }
    }
}

/// The notes ticked while creating a routine, with the web form's rules:
/// "All my notes" switches every other tick off, and a whole category
/// already covers its sub-categories, so their own ticks are not sent.
struct RoutineScopeSelection: Equatable {
    var allNotes: Bool = false
    var categoryIDs: Set<Int> = []
    var subCategoryIDs: Set<Int> = []

    /// What to send, or nil while nothing is chosen. IDs that are not in
    /// `options` (for example after the categories were reloaded) are left out.
    func scope(in options: RoutineScopeOptionsResponse) -> RoutineScope? {
        if allNotes { return .allNotes }
        let knownCategories = Set(options.categories.map(\.categoryID))
        let categories = categoryIDs.intersection(knownCategories)
        let subcategories = options.subcategories
            .filter { subCategoryIDs.contains($0.subCategoryID) && !categories.contains($0.categoryID) }
            .map(\.subCategoryID)
        guard !categories.isEmpty || !subcategories.isEmpty else { return nil }
        return .selected(categoryIDs: categories.sorted(), subCategoryIDs: Set(subcategories).sorted())
    }

    /// A sub-category can be ticked only while neither "All my notes" nor
    /// its whole category is ticked.
    func canChooseSubcategory(_ subcategory: RoutineScopeSubcategory) -> Bool {
        !allNotes && !categoryIDs.contains(subcategory.categoryID)
    }

    mutating func toggleCategory(_ id: Int) {
        if categoryIDs.contains(id) { categoryIDs.remove(id) } else { categoryIDs.insert(id) }
    }

    mutating func toggleSubcategory(_ id: Int) {
        if subCategoryIDs.contains(id) { subCategoryIDs.remove(id) } else { subCategoryIDs.insert(id) }
    }
}

/// The preview's count line, worded as on the web.
enum RoutinePreviewText {
    static func summary(_ preview: RoutinePreviewResponse) -> String {
        let matching = "\(preview.count) matching note\(preview.count == 1 ? "" : "s")"
        guard preview.count > preview.notes.count else { return matching }
        return "\(matching) · showing \(preview.notes.count) most recent"
    }
}

/// Server limits for a new routine, counted in Unicode code points as the
/// server's Python `len()` counts them.
enum RoutineLimits {
    static let maxNameLength = 120
    static let maxDescriptionLength = 4000

    /// `text` cut back to `limit` code points without splitting a character.
    static func limited(_ text: String, to limit: Int) -> String {
        var kept = ""
        var count = 0
        for character in text {
            count += character.unicodeScalars.count
            if count > limit { break }
            kept.append(character)
        }
        return kept
    }
}

// MARK: - Entities

struct RoutineSummary: Identifiable, Decodable, Equatable {
    let routineID: String
    let slug: String
    let name: String
    let description: String?
    let enabled: Bool
    let documentCount: Int?
    let openAskCount: Int?
    let updatedAt: String?
    let status: RoutineStatus?

    var id: String { routineID }

    enum CodingKeys: String, CodingKey {
        case routineID = "routine_id"
        case slug
        case name
        case description
        case enabled
        case documentCount = "document_count"
        case openAskCount = "open_ask_count"
        case updatedAt = "updated_at"
        case status
    }
}

/// The runner status the server attaches to every routine. The whole object
/// is null when the server can't work it out.
struct RoutineStatus: Decodable, Equatable {
    let verdict: String?
    /// When the latest report finished. Empty or missing when no report has
    /// arrived yet.
    let asOf: String?
    /// Whole hours since the routine was last heard from.
    let silentForHours: Int?
    /// Whether the owner has paused the routine.
    let paused: Bool?

    enum CodingKeys: String, CodingKey {
        case verdict
        case asOf = "as_of"
        case silentForHours = "silent_for_hours"
        case paused
    }

    init(verdict: String?, asOf: String? = nil, silentForHours: Int? = nil, paused: Bool? = nil) {
        self.verdict = verdict
        self.asOf = asOf
        self.silentForHours = silentForHours
        self.paused = paused
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // An odd value must hide or shorten the label, not fail the whole routines list.
        verdict = try? container.decodeIfPresent(String.self, forKey: .verdict)
        asOf = try? container.decodeIfPresent(String.self, forKey: .asOf)
        silentForHours = try? container.decodeIfPresent(Int.self, forKey: .silentForHours)
        paused = try? container.decodeIfPresent(Bool.self, forKey: .paused)
    }

    var hasReport: Bool {
        !(asOf ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Whether the owner has paused the routine. The server reports a
    /// paused routine with the PAUSED verdict, so that stands in when the
    /// flag itself is missing.
    var isPaused: Bool {
        paused ?? (verdict == RoutineHealth.paused.rawValue)
    }
}

/// What the status line shows: the health in plain words, "Status
/// unavailable" when the server sent no status at all (as the web does), or
/// nothing for a code this app doesn't know.
enum RoutineStatusDisplay: Equatable {
    case health(RoutineHealth)
    case unavailable
    case hidden

    static let unavailableLabel = "Status unavailable"

    init(status: RoutineStatus?) {
        if let health = RoutineHealth(status: status) {
            self = .health(health)
        } else if status == nil {
            self = .unavailable
        } else {
            self = .hidden
        }
    }
}

/// The verdict code in plain words, shared by the routines list and detail.
/// A missing or unrecognised code gives nil so the label hides instead of
/// showing a raw code.
enum RoutineHealth: String, CaseIterable {
    case ok = "OK"
    case nothingToDo = "NOTHING_TO_DO"
    case partial = "PARTIAL"
    case unknown = "UNKNOWN"
    case failed = "FAILED"
    case silent = "SILENT"
    case paused = "PAUSED"

    init?(status: RoutineStatus?) {
        guard let code = status?.verdict else { return nil }
        self.init(rawValue: code)
    }

    var label: String {
        switch self {
        case .ok: return "Up to date"
        case .nothingToDo: return "Nothing new"
        case .partial: return "Partly done"
        case .unknown: return "Waiting for first report"
        case .failed: return "Failed"
        case .silent: return "Not running"
        case .paused: return "Paused"
        }
    }

    /// The text of the status label, worded exactly like the web's status
    /// chip so both apps say the same thing about the same routine: the plain
    /// words, then how long ago the latest report came in ("Up to date · 42m
    /// ago"). A runner can itself report UNKNOWN; "Waiting for first report"
    /// is used only when no report exists, otherwise it reads "Result
    /// unclear". Nil when there is no status or the code is unknown.
    static func displayText(for status: RoutineStatus?, now: Date = Date()) -> String? {
        guard let status, let health = RoutineHealth(status: status) else { return nil }
        switch health {
        case .paused:
            return health.label
        case .unknown where !status.hasReport:
            return health.label
        case .silent:
            if status.hasReport {
                return "\(health.label) · no report for \(status.silentForHours ?? 0)h"
            }
            return "\(health.label) · no reports yet"
        default:
            let word = health == .unknown ? "Result unclear" : health.label
            guard let reported = reportDate(status.asOf) else { return word }
            return "\(word) · \(timeAgo(from: reported, to: now))"
        }
    }

    /// "42m ago", "5h ago" (up to 2 days), then "3d ago", as on the web.
    static func timeAgo(from date: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 48 * 3600 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }

    /// The report time is the runner's own timestamp. One without a time
    /// zone is read as UTC, as the server does.
    private static func reportDate(_ iso: String?) -> Date? {
        guard let iso = iso?.trimmingCharacters(in: .whitespaces), !iso.isEmpty else { return nil }
        return RoutineDateParser.date(from: iso) ?? RoutineDateParser.date(from: iso + "Z")
    }
}

struct RoutineDocumentMeta: Identifiable, Decodable, Equatable {
    let slug: String
    let title: String
    let summary: String?
    let docKind: String?
    let sortOrder: Int?
    let revision: Int
    let updatedAt: String?

    var id: String { slug }

    enum CodingKeys: String, CodingKey {
        case slug
        case title
        case summary
        case docKind = "doc_kind"
        case sortOrder = "sort_order"
        case revision
        case updatedAt = "updated_at"
    }
}

struct RoutineScopeCategory: Identifiable, Decodable, Equatable {
    let categoryID: Int
    let name: String

    var id: Int { categoryID }

    enum CodingKeys: String, CodingKey {
        case categoryID = "category_id"
        case name
    }
}

struct RoutineScopeSubcategory: Identifiable, Decodable, Equatable {
    let subCategoryID: Int
    let categoryID: Int
    let name: String

    var id: Int { subCategoryID }

    enum CodingKeys: String, CodingKey {
        case subCategoryID = "sub_category_id"
        case categoryID = "category_id"
        case name
    }
}

struct RoutinePreviewNote: Identifiable, Decodable, Equatable {
    let noteID: String
    let title: String?
    let preview: String?

    var id: String { noteID }

    enum CodingKeys: String, CodingKey {
        case noteID = "note_id"
        case title
        case preview
    }
}

/// The runner instructions are only published inside the web's "Connect
/// your runner" page (GET /routines/<slug>/connect), in the read-only text
/// box with id `runner-instructions`. This pulls that text back out so the
/// app hands over exactly what the web shows.
enum RunnerInstructionsPage {
    static func instructions(fromHTML html: String) -> String? {
        guard let open = html.range(of: "<textarea id=\"runner-instructions\""),
              let tagEnd = html.range(of: ">", range: open.upperBound..<html.endIndex),
              let close = html.range(of: "</textarea>", range: tagEnd.upperBound..<html.endIndex)
        else { return nil }
        let text = unescape(String(html[tagEnd.upperBound..<close.lowerBound]))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// Reverses the page's HTML escaping (`&lt;`, `&amp;`, `&#34;`…) in one
    /// pass, so an escaped ampersand is never unescaped twice.
    static func unescape(_ text: String) -> String {
        let named: [String: String] = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'"]
        var result = ""
        var rest = text[...]
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            let afterAmp = rest.index(after: amp)
            if let semicolon = rest[afterAmp...].prefix(10).firstIndex(of: ";") {
                let entity = String(rest[afterAmp..<semicolon])
                if let decoded = decode(entity, named: named) {
                    result += decoded
                    rest = rest[rest.index(after: semicolon)...]
                    continue
                }
            }
            result.append("&")
            rest = rest[afterAmp...]
        }
        result += rest
        return result
    }

    private static func decode(_ entity: String, named: [String: String]) -> String? {
        if let value = named[entity] { return value }
        guard entity.hasPrefix("#") else { return nil }
        let digits = entity.dropFirst()
        let code: UInt32?
        if digits.hasPrefix("x") || digits.hasPrefix("X") {
            code = UInt32(digits.dropFirst(), radix: 16)
        } else {
            code = UInt32(digits)
        }
        guard let code, let scalar = Unicode.Scalar(code) else { return nil }
        return String(Character(scalar))
    }
}

// GET /api/routines/<slug>/documents/<doc_slug>
struct RoutineDocument: Identifiable, Decodable {
    let documentID: String
    let slug: String
    let title: String
    let body: String
    /// Optional self-contained presentation; `body` remains the searchable,
    /// accessible Markdown fallback and the source for copying text.
    let interactiveHTML: String?
    let summary: String?
    let docKind: String?
    let revision: Int
    let updatedAt: String?

    var id: String { documentID }

    enum CodingKeys: String, CodingKey {
        case documentID = "document_id"
        case slug
        case title
        case body
        case interactiveHTML = "interactive_html"
        case summary
        case docKind = "doc_kind"
        case revision
        case updatedAt = "updated_at"
    }
}

enum RoutineAskStatus: String {
    case open
    case answered
    case applied
    case withdrawn
}

enum RoutineAnswerChoice: String, CaseIterable {
    case approve
    case edit
    case deny

    var label: String {
        switch self {
        case .approve: return "Approve"
        case .edit: return "Edit"
        case .deny: return "Deny"
        }
    }
}

struct RoutineAsk: Identifiable, Decodable, Equatable {
    let askID: String
    let externalAskID: String?
    let batchID: String?
    let title: String
    let context: String?
    let recommendation: String?
    let proposedChange: String?
    let safeDefault: String?
    let status: String
    let answerChoice: String?
    let answerText: String?
    let answeredAt: String?
    let appliedAt: String?
    let supersedesAskID: String?
    let revision: Int
    let createdAt: String?
    let updatedAt: String?

    var id: String { askID }

    var askStatus: RoutineAskStatus? { RoutineAskStatus(rawValue: status) }
    var isOpen: Bool { askStatus == .open }

    enum CodingKeys: String, CodingKey {
        case askID = "ask_id"
        case externalAskID = "external_ask_id"
        case batchID = "batch_id"
        case title
        case context
        case recommendation
        case proposedChange = "proposed_change"
        case safeDefault = "safe_default"
        case status
        case answerChoice = "answer_choice"
        case answerText = "answer_text"
        case answeredAt = "answered_at"
        case appliedAt = "applied_at"
        case supersedesAskID = "supersedes_ask_id"
        case revision
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Timestamp helpers

// Server timestamps are ISO-8601 UTC with a trailing "Z"; fractional seconds
// are present whenever the DB value carries microseconds, so try both.
enum RoutineDateParser {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func date(from iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        return withFraction.date(from: iso) ?? plain.date(from: iso)
    }

    static func relative(_ iso: String?) -> String? {
        guard let date = date(from: iso) else { return nil }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        return relative.localizedString(for: date, relativeTo: Date())
    }
}

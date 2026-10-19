import Foundation

// Models for the Routines API served by the Flask frontend
// (The_Dump_Front_End/routes/routines_routes.py). Only the fields the UI
// reads are declared — Decodable ignores unknown keys, and `scope` is JSONB
// on the server so it is deliberately left out.

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

// MARK: - Requests

struct RoutineAnswerRequest: Encodable {
    let choice: String
    let text: String?
    let revision: Int
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

    enum CodingKeys: String, CodingKey {
        case verdict
        case asOf = "as_of"
        case silentForHours = "silent_for_hours"
    }

    init(verdict: String?, asOf: String? = nil, silentForHours: Int? = nil) {
        self.verdict = verdict
        self.asOf = asOf
        self.silentForHours = silentForHours
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // An odd value must hide or shorten the label, not fail the whole routines list.
        verdict = try? container.decodeIfPresent(String.self, forKey: .verdict)
        asOf = try? container.decodeIfPresent(String.self, forKey: .asOf)
        silentForHours = try? container.decodeIfPresent(Int.self, forKey: .silentForHours)
    }

    var hasReport: Bool {
        !(asOf ?? "").trimmingCharacters(in: .whitespaces).isEmpty
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

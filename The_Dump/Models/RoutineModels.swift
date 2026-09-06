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
    let documents: [RoutineDocumentMeta]

    enum CodingKeys: String, CodingKey {
        case routineID = "routine_id"
        case slug
        case name
        case description
        case enabled
        case updatedAt = "updated_at"
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

struct RoutineDocumentRevision: Identifiable, Decodable, Equatable {
    let revision: Int
    let title: String?
    let createdAt: String?

    var id: Int { revision }

    enum CodingKeys: String, CodingKey {
        case revision
        case title
        case createdAt = "created_at"
    }
}

// GET /api/routines/<slug>/documents/<doc_slug>
struct RoutineDocument: Identifiable, Decodable {
    let documentID: String
    let slug: String
    let title: String
    let body: String
    let summary: String?
    let docKind: String?
    let revision: Int
    let updatedAt: String?
    let revisions: [RoutineDocumentRevision]?

    var id: String { documentID }

    enum CodingKeys: String, CodingKey {
        case documentID = "document_id"
        case slug
        case title
        case body
        case summary
        case docKind = "doc_kind"
        case revision
        case updatedAt = "updated_at"
        case revisions
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

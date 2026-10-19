import Foundation

// MARK: - Stacks

// Matches the response from GET /api/stack/<stack_id>
struct StackResponse: Decodable {
    let stack: StackInfo
    /// Every note in the stack, newest first.
    let notes: [NotePreview]
}

struct StackInfo: Decodable {
    let stackId: String
    let title: String?
    let origin: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case stackId = "stack_id"
        case title
        case origin
        case createdAt = "created_at"
    }
}

struct StackNotesRequest: Encodable {
    let noteIds: [String]

    enum CodingKeys: String, CodingKey {
        case noteIds = "note_ids"
    }
}

struct StackNotesResponse: Decodable {
    let stackId: String
    let stackedCount: Int

    enum CodingKeys: String, CodingKey {
        case stackId = "stack_id"
        case stackedCount = "stacked_count"
    }
}

struct UnstackNotesRequest: Encodable {
    let stackId: String

    enum CodingKeys: String, CodingKey {
        case stackId = "stack_id"
    }
}

// MARK: - Bulk actions

struct BulkDeleteNotesRequest: Encodable {
    let noteIds: [String]

    enum CodingKeys: String, CodingKey {
        case noteIds = "note_ids"
    }
}

struct BulkDeleteNotesResponse: Decodable {
    let deletedCount: Int

    enum CodingKeys: String, CodingKey {
        case deletedCount = "deleted_count"
    }
}

/// POST /bulk_update_notes. Set exactly one of `category` (an active
/// category's name; the server refuses a blank or archived one) or `type`.
/// Nil fields are left out of the body, which the server reads as "leave
/// unchanged".
struct BulkUpdateNotesRequest: Encodable {
    let noteIds: [String]
    var category: String?
    var type: String?

    enum CodingKeys: String, CodingKey {
        case noteIds = "note_ids"
        case category
        case type
    }
}

struct BulkUpdateNotesResponse: Decodable {
    let updatedCount: Int

    enum CodingKeys: String, CodingKey {
        case updatedCount = "updated_count"
    }
}

/// The stack and bulk routes explain a failure under "message" (for example
/// "A note must have a category. Choose one from the list."); a few server
/// errors use "error".
struct NotesActionErrorResponse: Decodable {
    let message: String?
    let error: String?
}

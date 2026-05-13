import Foundation

// MARK: - Re-categorize past notes
// Response shape is provisional and may change when the backend endpoint
// ships; the request type is intentionally omitted until that point.

struct RecategorizePastNotesResponse: Decodable {
    let status: String?
    let affectedCount: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case affectedCount = "affected_count"
    }
}

// MARK: - Recategorize job API (POST /api/recategorize + GET /api/recategorize/status/{id})

enum RecategorizeScope: String, Codable, CaseIterable, Identifiable {
    case all
    case category
    case uncategorized

    var id: String { rawValue }
}

struct StartRecategorizeRequest: Encodable {
    let scope: RecategorizeScope
    let categoryId: Int?

    enum CodingKeys: String, CodingKey {
        case scope
        case categoryId = "category_id"
    }
}

struct StartRecategorizeResponse: Decodable {
    let jobId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
    }
}

enum RecategorizeStatusValue: String, Decodable {
    case pending
    case running
    case done
    case failed

    var isTerminal: Bool { self == .done || self == .failed }
}

struct RecategorizeJobStatus: Decodable {
    let jobId: String
    let scope: RecategorizeScope
    let scopeCategoryId: Int?
    let status: RecategorizeStatusValue
    let total: Int
    let processed: Int
    let moved: Int
    let skippedNoEmbeddings: Int
    let errors: Int
    let errorMessage: String?
    let createdAt: String
    let startedAt: String?
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case scope
        case scopeCategoryId = "scope_category_id"
        case status
        case total
        case processed
        case moved
        case skippedNoEmbeddings = "skipped_no_embeddings"
        case errors
        case errorMessage = "error_message"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

// MARK: - Delete / archive (not implemented server-side yet)

enum DeleteCategoryDisposition: Equatable {
    case recategorize           // re-run AI on this category's notes
    case moveAll(targetName: String)
    case archiveInstead
}

// MARK: - Local presentation models

/// View model for a single category row. Bridges what the backend currently
/// returns with the optional fields the new UI wants to surface.
struct CategoryListItem: Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    let definition: String
    let keywords: [String]
    let source: String
    let noteCount: Int
    let subCatCount: Int
    let inProcessCount: Int
    let archived: Bool
    let archivedAt: String?

    var isLocked: Bool { inProcessCount > 0 }

    static func make(from response: CategoryResponse, noteCount: Int) -> CategoryListItem {
        CategoryListItem(
            id: response.categoryId,
            name: response.name,
            definition: response.definition,
            keywords: response.keywords,
            source: response.source,
            noteCount: noteCount,
            subCatCount: response.subCatCount ?? 0,
            inProcessCount: response.inProcessCount ?? 0,
            archived: response.archived ?? false,
            archivedAt: response.archivedAt
        )
    }
}

// MARK: - Emoji storage (local-only until backend adds an `emoji` field)

enum CategoryEmojiStore {
    private static let key = "categoryEmojis.v1"
    private static let defaultEmoji = "📁"

    static func emoji(for categoryId: Int) -> String {
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        return dict[String(categoryId)] ?? defaultEmoji
    }

    static func setEmoji(_ emoji: String, for categoryId: Int) {
        var dict = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            dict.removeValue(forKey: String(categoryId))
        } else {
            dict[String(categoryId)] = trimmed
        }
        UserDefaults.standard.set(dict, forKey: key)
    }
}

// MARK: - Constants

enum CategoryLimits {
    /// Client-side cap until the backend exposes one. Drives the cap meter
    /// and the disabled state of the "Add category" button.
    static let maxActiveCategories: Int = 15
}

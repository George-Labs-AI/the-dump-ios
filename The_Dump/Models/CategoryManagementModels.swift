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
    /// Set only when the category is archived right after this re-sort, so
    /// the backend never moves a note back into it — the same body the web
    /// app sends. Nil keys are left out of the JSON.
    let archiving: Bool?
    let excludeCategoryIds: [Int]?

    init(scope: RecategorizeScope, categoryId: Int?, archiving: Bool = false) {
        self.scope = scope
        self.categoryId = categoryId
        if archiving, let categoryId {
            self.archiving = true
            self.excludeCategoryIds = [categoryId]
        } else {
            self.archiving = nil
            self.excludeCategoryIds = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case scope
        case categoryId = "category_id"
        case archiving
        case excludeCategoryIds = "exclude_category_ids"
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

enum RecategorizeStatusValue: String, Codable {
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
    /// Always 0 since the backend stopped using embeddings to re-sort notes;
    /// the key is still sent so shipped clients keep decoding the response.
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

// MARK: - Restore (POST /api/categories/{id}/restore)

struct RestoreCategoryResponse: Decodable {
    let status: String
    let categoryId: Int
    let restoredSubcategoryCount: Int
    /// Only present when restoring a category that is already active (idempotent no-op).
    let alreadyActive: Bool?

    enum CodingKeys: String, CodingKey {
        case status
        case categoryId = "category_id"
        case restoredSubcategoryCount = "restored_subcategory_count"
        case alreadyActive = "already_active"
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

/// Resolves category note counts strictly by category ID.
///
/// The iOS client should treat `category_id` from `/api/note_counts` as the
/// sole source of truth for per-category counts. If the backend omits
/// `category_details` or a row's `category_id`, the client intentionally does
/// not fall back to category names.
enum CategoryCountStore {
    static func countsByCategoryID(from response: NoteCountsResponse) -> [Int: Int] {
        guard let details = response.categoryDetails else { return [:] }

        return details.reduce(into: [Int: Int]()) { partial, detail in
            guard let categoryID = detail.categoryID else { return }
            partial[categoryID, default: 0] += max(0, detail.count)
        }
    }

    static func noteCount(for categoryId: Int, countsByCategoryID: [Int: Int]) -> Int {
        countsByCategoryID[categoryId] ?? 0
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

    /// Longest category name the server accepts (it rejects longer ones with
    /// a 400). The web's Settings field uses the same number.
    static let maxNameLength: Int = 80

    /// The length the server checks: Unicode code points (what Python's
    /// `len()` counts) after trimming spaces around the name.
    static func nameLength(_ text: String) -> Int {
        TextLimits.nameLength(text)
    }

    /// `text` cut back so that `nameLength` is at most `maxNameLength`.
    /// Spaces around the name don't count, and a character is never split,
    /// so an emoji at the limit is dropped whole.
    static func limitedName(_ text: String) -> String {
        TextLimits.limitedName(text, to: maxNameLength)
    }

    static func isNameAtLimit(_ text: String) -> Bool {
        nameLength(text) >= maxNameLength
    }
}

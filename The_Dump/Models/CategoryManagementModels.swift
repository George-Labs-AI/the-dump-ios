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
    /// The emoji saved on the server, or nil when none has been chosen.
    var emoji: String?

    var isLocked: Bool { inProcessCount > 0 }

    /// What the app shows for this category: its emoji, or 📁 without one.
    var displayEmoji: String { CategoryEmoji.displayed(emoji) }

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
            archivedAt: response.archivedAt,
            emoji: response.emoji
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

// MARK: - Emoji

/// A category's emoji is saved on the server, so every phone and the web show
/// the same one. These are the server's rules for it, so the app never sends
/// an emoji the server would refuse.
enum CategoryEmoji {
    /// Shown for a category with no emoji chosen.
    static let placeholder = "📁"

    /// The longest emoji the server accepts, counted in Unicode code points.
    /// One emoji can be several code points (skin tones, flags, families),
    /// and 16 leaves room for any single one.
    static let maxCodePoints = 16

    static func displayed(_ emoji: String?) -> String {
        guard let emoji, !emoji.isEmpty else { return placeholder }
        return emoji
    }

    /// `text` as the server will save it, or nil when the server would refuse
    /// it. As on the server, spaces around it are trimmed, and what is left
    /// must have no spaces or control characters inside, be at most
    /// `maxCodePoints` code points, and contain a character outside plain
    /// ASCII, so a letter or a digit on its own is refused.
    static func validated(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let scalars = trimmed.unicodeScalars
        guard !trimmed.isEmpty,
              scalars.count <= maxCodePoints,
              !scalars.contains(where: { $0.properties.isWhitespace }),
              !scalars.contains(where: { $0.properties.generalCategory == .control }),
              scalars.contains(where: { !$0.isASCII })
        else { return nil }
        return trimmed
    }

    /// What the emoji field keeps after an edit, from what it held before and
    /// what is in it now. The last character wins, so typing a new emoji
    /// replaces the old one. An emptied field stays empty, which means no
    /// emoji. A character the server would refuse, such as a letter or a
    /// space, is ignored and the field keeps what it had.
    static func fieldValue(previous: String, edited: String) -> String {
        if edited.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "" }
        return validated(String(edited.suffix(1))) ?? previous
    }
}

/// Emoji chosen on this phone before emoji were saved on the server, by
/// category ID. `CategoryEmojiMover` sends them to the server and empties it;
/// the only thing that still adds to it is a new category whose emoji
/// couldn't be sent, so that the next load sends it.
nonisolated struct CategoryEmojiStore {
    static let key = "categoryEmojis.v1"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var entries: [Int: String] {
        stored.reduce(into: [Int: String]()) { result, entry in
            if let categoryId = Int(entry.key) { result[categoryId] = entry.value }
        }
    }

    func set(_ emoji: String, for categoryId: Int) {
        var dict = stored
        dict[String(categoryId)] = emoji
        defaults.set(dict, forKey: Self.key)
    }

    /// Forgets one category's emoji, and the whole key once none are left.
    func remove(_ categoryId: Int) {
        var dict = stored
        dict.removeValue(forKey: String(categoryId))
        if dict.isEmpty {
            defaults.removeObject(forKey: Self.key)
        } else {
            defaults.set(dict, forKey: Self.key)
        }
    }

    private var stored: [String: String] {
        defaults.dictionary(forKey: Self.key) as? [String: String] ?? [:]
    }
}

/// Decides what happens to each emoji in `CategoryEmojiStore` once the
/// server's list of categories has loaded.
enum CategoryEmojiMove {
    struct ServerCategory {
        let id: Int
        let emoji: String?
        let archived: Bool
    }

    struct Plan: Equatable {
        /// Emoji to save on the server, by category ID.
        var send: [Int: String] = [:]
        /// Categories whose stored emoji is forgotten without being sent.
        var drop: Set<Int> = []
    }

    static func plan(local: [Int: String], server: [ServerCategory]) -> Plan {
        let serverById = Dictionary(server.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var plan = Plan()
        for (categoryId, localEmoji) in local {
            // Not in this account's list, so it may belong to another account
            // that used this phone before. Leave it for that account.
            guard let category = serverById[categoryId] else { continue }

            // The server's emoji wins, so one chosen on the web or on another
            // phone is never overwritten.
            if let serverEmoji = category.emoji, !serverEmoji.isEmpty {
                plan.drop.insert(categoryId)
                continue
            }

            // 📁 is what the app shows when there is no emoji, so it is never
            // sent; an emoji the server would refuse can never move.
            guard let emoji = CategoryEmoji.validated(localEmoji),
                  emoji != CategoryEmoji.placeholder else {
                plan.drop.insert(categoryId)
                continue
            }

            // The server doesn't change archived categories. The emoji stays
            // on the phone and moves if the category is restored.
            if category.archived { continue }

            plan.send[categoryId] = emoji
        }
        return plan
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

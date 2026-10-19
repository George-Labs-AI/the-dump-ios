import Foundation

// MARK: - API Responses

// Matches the response from GET /api/note_counts
struct NoteCountsResponse: Decodable {
    let categories: [String: Int]?
    let categoryDetails: [CategoryDetail]?
    let sub_categories: [String: Int]?
    let note_types: [String: Int]?
    let mime_types: [String: Int]?
    let date_groups: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case categories
        case categoryDetails = "category_details"
        case sub_categories
        case note_types
        case mime_types
        case date_groups
    }

    var categoryCounts: [String: Int] { categories ?? [:] }
    var subCategoryCounts: [String: Int] { sub_categories ?? [:] }
    var noteTypeCounts: [String: Int] { note_types ?? [:] }
    var mimeTypeCounts: [String: Int] { mime_types ?? [:] }
    var dateGroupCounts: [String: Int] { date_groups ?? [:] }

    var hasAnyCategories: Bool {
        if let categoryDetails {
            return !categoryDetails.isEmpty
        }
        return !categoryCounts.isEmpty
    }

    var categoryBucketCount: Int {
        categoryDetails?.count ?? categoryCounts.count
    }
}

struct CategoryDetail: Decodable, Identifiable {
    let categoryID: Int?
    let categoryName: String
    let count: Int
    let isRetired: Bool

    var id: String {
        if let categoryID {
            return "category-\(categoryID)"
        }
        return categoryName
    }

    enum CodingKeys: String, CodingKey {
        case categoryID = "category_id"
        case categoryName = "category_name"
        case count
        case isRetired = "is_retired"
    }
}

// Matches the response from GET /pull_notes
struct NoteListResponse: Codable {
    let notes: [NotePreview]
    let next_cursor_time: String?
    let next_cursor_id: String?
    let has_more: Bool
    let next_offset: Int?
    let mode: String?
}

// Matches the response from POST /api/pull_full_notes
struct NoteDetailResponse: Codable {
    let notes: [NoteDetail]
}

// MARK: - Data Entities

// Represents a single note in the list view (lightweight)
struct NotePreview: Identifiable, Codable {
    let organized_note_id: String
    let title: String?
    let preview: String
    let note_content_modified: String
    let category_id: Int?
    let category_name: String?
    let note_type: String?
    let mime_type: String?
    let sub_cat_names: [String]?
    /// Who sent an emailed note; nil (or blank) for the account owner's own notes.
    let author: String?
    /// Stack fields. A list fetched with stacks=1 sends stack_size and
    /// stack_total on the one row that stands for a whole stack; a stack's
    /// members (from /api/stack/<id>) carry stack_id but no counts.
    let stack_id: String?
    /// How many of the stack's notes match the list's filters.
    let stack_size: Int?
    /// How many notes the whole stack holds.
    let stack_total: Int?
    
    // Map API ID to Swift's Identifiable ID
    var id: String { organized_note_id }
}

// Represents the full note content (heavyweight)
struct NoteDetail: Identifiable, Codable {
    let organized_note_id: String
    let title: String?
    let note_content: String
    let note_content_modified: String
    let category_id: Int?
    let category_name: String?
    let sub_cat_names: [String]?
    let tags: [String]?
    let mime_type: String?
    let note_type: String?
    /// Who sent an emailed note; nil (or blank) for the account owner's own notes.
    let author: String?
    /// Whether the note has an original file (photo, recording, document)
    /// to open. Nil from servers that don't send it.
    let has_asset: Bool?
    
    var id: String { organized_note_id }
}

// MARK: - Sub-category lists

// The server has sent sub_cat_names with a null entry in it (a stale
// sub-category ID stored by the backend's recheck). Decoding that as
// [String] failed the whole notes response and blanked Browse, so these
// models drop empty entries instead.
extension KeyedDecodingContainer {
    func decodeSubCategoryNames(forKey key: Key) throws -> [String]? {
        try decodeIfPresent([String?].self, forKey: key)?.compactMap { $0 }
    }
}

extension NotePreview {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        organized_note_id = try c.decode(String.self, forKey: .organized_note_id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        preview = try c.decode(String.self, forKey: .preview)
        note_content_modified = try c.decode(String.self, forKey: .note_content_modified)
        category_id = try c.decodeIfPresent(Int.self, forKey: .category_id)
        category_name = try c.decodeIfPresent(String.self, forKey: .category_name)
        note_type = try c.decodeIfPresent(String.self, forKey: .note_type)
        mime_type = try c.decodeIfPresent(String.self, forKey: .mime_type)
        sub_cat_names = try c.decodeSubCategoryNames(forKey: .sub_cat_names)
        author = try c.decodeIfPresent(String.self, forKey: .author)
        stack_id = try c.decodeIfPresent(String.self, forKey: .stack_id)
        stack_size = try c.decodeIfPresent(Int.self, forKey: .stack_size)
        stack_total = try c.decodeIfPresent(Int.self, forKey: .stack_total)
    }
}

extension NoteDetail {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        organized_note_id = try c.decode(String.self, forKey: .organized_note_id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        note_content = try c.decode(String.self, forKey: .note_content)
        note_content_modified = try c.decode(String.self, forKey: .note_content_modified)
        category_id = try c.decodeIfPresent(Int.self, forKey: .category_id)
        category_name = try c.decodeIfPresent(String.self, forKey: .category_name)
        sub_cat_names = try c.decodeSubCategoryNames(forKey: .sub_cat_names)
        tags = try c.decodeIfPresent([String].self, forKey: .tags)
        mime_type = try c.decodeIfPresent(String.self, forKey: .mime_type)
        note_type = try c.decodeIfPresent(String.self, forKey: .note_type)
        author = try c.decodeIfPresent(String.self, forKey: .author)
        has_asset = try c.decodeIfPresent(Bool.self, forKey: .has_asset)
    }
}

// MARK: - Edit Note

struct EditNoteRequest: Codable {
    let noteId: String
    var entries: String?
    var title: String?
    var categoryId: Int?
    var subCategories: [String]?
    var type: String?
    var tags: [String]?

    enum CodingKeys: String, CodingKey {
        case noteId = "note_id"
        case entries
        case title
        case categoryId = "category_id"
        case subCategories = "sub_categories"
        case type
        case tags
    }
}

struct EditNoteResponse: Codable {
    let success: Bool?
    let note: EditNoteResponseNote?
    let error: String?
}

struct EditNoteResponseNote: Codable, Identifiable {
    let organized_note_id: String
    let title: String?
    let note_content: String?
    let note_content_modified: String?
    let category_id: Int?
    let category_name: String?
    let sub_cat_names: [String]?
    let note_type: String?
    let mime_type: String?

    var id: String { organized_note_id }
}

extension EditNoteResponseNote {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        organized_note_id = try c.decode(String.self, forKey: .organized_note_id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        note_content = try c.decodeIfPresent(String.self, forKey: .note_content)
        note_content_modified = try c.decodeIfPresent(String.self, forKey: .note_content_modified)
        category_id = try c.decodeIfPresent(Int.self, forKey: .category_id)
        category_name = try c.decodeIfPresent(String.self, forKey: .category_name)
        sub_cat_names = try c.decodeSubCategoryNames(forKey: .sub_cat_names)
        note_type = try c.decodeIfPresent(String.self, forKey: .note_type)
        mime_type = try c.decodeIfPresent(String.self, forKey: .mime_type)
    }
}

// MARK: - Category Map

// Matches the response from GET /api/category_map. Both lists are keyed and
// spelled in lower case ("work": ["meetings", "project ideas"]); only active
// categories and sub-categories are included.
struct CategoryMapResponse: Decodable {
    let categories: [String]?
    let subcategoriesByCategory: [String: [String]]?

    enum CodingKeys: String, CodingKey {
        case categories
        case subcategoriesByCategory = "subcategories_by_category"
    }
}

// MARK: - Note Types

// Matches the response from GET /api/note_types
struct NoteTypesResponse: Decodable {
    let note_types: [String]
}

// MARK: - Delete Note

struct DeleteNoteRequest: Codable {
    let noteId: String

    enum CodingKeys: String, CodingKey {
        case noteId = "note_id"
    }
}

struct DeleteNoteResponse: Codable {
    let success: Bool
    let note_id: String
}

// MARK: - Categories

struct Category: Codable {
    let name: String
    let definition: String?
    let keywords: [String]?
    let source: String?

    init(name: String, definition: String? = nil, keywords: [String]? = nil, source: String? = nil) {
        self.name = name
        self.definition = definition
        self.keywords = keywords
        self.source = source
    }
}

struct AddCategoriesRequest: Codable {
    let categories: [Category]
}

/// Represents a category as returned by the server after save (includes database IDs and timestamps)
struct CategoryResponse: Codable {
    let categoryId: Int
    let name: String
    let definition: String
    let keywords: [String]
    let source: String
    let dateAdded: String
    let lastModifiedDate: String

    /// The category's emoji; nil when none has been chosen.
    let emoji: String?
    /// Whether the server sent the `emoji` key at all, as opposed to sending
    /// it as null. A server from before emoji were saved leaves it out, and
    /// the app doesn't try to move emoji from this phone to one of those.
    let sendsEmoji: Bool
    // Optional forward-compatible fields. Server doesn't return these yet;
    // when it does, decoders pick them up automatically.
    let archived: Bool?
    let archivedAt: String?
    let inProcessCount: Int?
    let subCatCount: Int?

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case name, definition, keywords, source
        case dateAdded = "date_added"
        case lastModifiedDate = "last_modified_date"
        case emoji
        case archived
        case archivedAt = "archived_at"
        case inProcessCount = "in_process_count"
        case subCatCount = "sub_cat_count"
    }
}

extension CategoryResponse {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        categoryId = try container.decode(Int.self, forKey: .categoryId)
        name = try container.decode(String.self, forKey: .name)
        definition = try container.decode(String.self, forKey: .definition)
        keywords = try container.decode([String].self, forKey: .keywords)
        source = try container.decode(String.self, forKey: .source)
        dateAdded = try container.decode(String.self, forKey: .dateAdded)
        lastModifiedDate = try container.decode(String.self, forKey: .lastModifiedDate)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji)
        sendsEmoji = container.contains(.emoji)
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived)
        archivedAt = try container.decodeIfPresent(String.self, forKey: .archivedAt)
        inProcessCount = try container.decodeIfPresent(Int.self, forKey: .inProcessCount)
        subCatCount = try container.decodeIfPresent(Int.self, forKey: .subCatCount)
    }
}

struct AddCategoriesResponse: Codable {
    let status: String
    let updatedCount: Int
    let categories: [CategoryResponse]

    enum CodingKeys: String, CodingKey {
        case status
        case updatedCount = "updated_count"
        case categories
    }
}

// MARK: - Category Update (PATCH /api/categories/{id})

struct CategoryUpdateRequest: Encodable {
    let categoryName: String?
    let categoryDescription: String?
    let keywords: [String]?
    /// A new emoji, or "" to clear it. Nil leaves the emoji as it is.
    let emoji: String?

    init(
        categoryName: String? = nil,
        categoryDescription: String? = nil,
        keywords: [String]? = nil,
        emoji: String? = nil
    ) {
        self.categoryName = categoryName
        self.categoryDescription = categoryDescription
        self.keywords = keywords
        self.emoji = emoji
    }

    enum CodingKeys: String, CodingKey {
        case categoryName = "category_name"
        case categoryDescription = "category_description"
        case keywords
        case emoji
    }
}

struct UpdatedCategory: Codable {
    let categoryId: Int
    let categoryName: String
    let categoryDescription: String
    let keywords: [String]
    /// Always false since the server stopped embedding categories on save;
    /// kept because this client requires the key.
    let embeddingRefreshed: Bool
    /// The category's emoji after the save; nil when it has none.
    let emoji: String?

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case categoryName = "category_name"
        case categoryDescription = "category_description"
        case keywords
        case embeddingRefreshed = "embedding_refreshed"
        case emoji
    }
}

struct UpdatedCategoryResponse: Codable {
    let status: String
    let category: UpdatedCategory
}

// MARK: - Category Archive (POST /api/categories/{id}/archive)

struct ArchiveCategoryResponse: Decodable {
    let status: String
    let categoryId: Int
    let archivedSubcategoryCount: Int
    /// Only present when archiving an already-archived category (idempotent no-op).
    let alreadyArchived: Bool?

    enum CodingKeys: String, CodingKey {
        case status
        case categoryId = "category_id"
        case archivedSubcategoryCount = "archived_subcategory_count"
        case alreadyArchived = "already_archived"
    }
}

struct FetchCategoriesResponse: Codable {
    let categories: [CategoryResponse]
}

// MARK: - Sub-Categories

struct CreateSubCategoryRequest: Codable {
    let categoryName: String
    let subCatName: String
    let subCatDescription: String?
    let subCatKeywords: String?

    enum CodingKeys: String, CodingKey {
        case categoryName = "category_name"
        case subCatName = "sub_cat_name"
        case subCatDescription = "sub_cat_description"
        case subCatKeywords = "sub_cat_keywords"
    }
}

struct CreateSubCategoryResponse: Codable {
    let success: Bool?
    let error: String?
}

// MARK: - Original Asset

struct NoteAssetResponse: Codable, Equatable {
    let signed_url: String
    let content_type: String
    let filename: String
    let expires_in: Int
}

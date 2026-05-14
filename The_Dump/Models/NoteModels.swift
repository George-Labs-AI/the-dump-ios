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
    
    var id: String { organized_note_id }
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

    // Optional forward-compatible fields. Server doesn't return these yet;
    // when it does, decoders pick them up automatically.
    let emoji: String?
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

    enum CodingKeys: String, CodingKey {
        case categoryName = "category_name"
        case categoryDescription = "category_description"
        case keywords
    }
}

struct UpdatedCategory: Codable {
    let categoryId: Int
    let categoryName: String
    let categoryDescription: String
    let keywords: [String]
    let embeddingRefreshed: Bool

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case categoryName = "category_name"
        case categoryDescription = "category_description"
        case keywords
        case embeddingRefreshed = "embedding_refreshed"
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

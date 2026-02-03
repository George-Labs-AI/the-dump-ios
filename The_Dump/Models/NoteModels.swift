import Foundation

// MARK: - API Responses

// Matches the response from GET /api/note_counts
struct NoteCountsResponse: Codable {
    let categories: [String: Int]
    let sub_categories: [String: Int]
    let note_types: [String: Int]
    let mime_types: [String: Int]
    let date_groups: [String: Int]
}

// Matches the response from GET /pull_notes
struct NoteListResponse: Codable {
    let notes: [NotePreview]
    let next_cursor_time: String?
    let next_cursor_id: String?
    let has_more: Bool
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
    var category: String?
    var subCategories: [String]?
    var type: String?
    var tags: [String]?

    enum CodingKeys: String, CodingKey {
        case noteId = "note_id"
        case entries
        case title
        case category
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
    let category_name: String?
    let sub_cat_names: [String]?
    let note_type: String?
    let mime_type: String?

    var id: String { organized_note_id }
}

import Foundation

// Wire types and pure status mapping for `POST /api/file_status`
// (docs/note-status-contract.md, Phase 1).
//
// This file is deliberately dependency-free (Foundation only, no networking,
// no app singletons) so the decode + mapping layer compiles standalone and
// can be exercised outside the app target. Keep it that way.

/// Request body: `{ "file_uuids": ["uuid-1", "uuid-2"] }`.
struct FileStatusRequest: Codable, Equatable, Sendable {
    let fileUuids: [String]

    enum CodingKeys: String, CodingKey {
        case fileUuids = "file_uuids"
    }
}

/// Response body: `{ "statuses": [ ... ] }` — one entry per requested uuid,
/// in request order.
struct FileStatusResponse: Codable, Equatable, Sendable {
    let statuses: [FileStatusEntry]
}

/// One per-uuid status entry. `status` is kept as a raw string so unknown
/// values the server may add later still decode (forward compatibility);
/// interpretation happens in `NoteStatusMapping`.
struct FileStatusEntry: Codable, Equatable, Sendable {
    let fileUuid: String
    let status: String
    /// `transcribed` only — first 512 chars of intake_notes.note_content.
    let noteContentPreview: String?
    /// `transcribed` only — voice / image / text / file.
    let mediaType: String?
    /// `completed` only.
    let organizedNoteId: String?
    let title: String?
    let categoryId: Int?
    let categoryName: String?
    /// `failed` only.
    let error: String?

    enum CodingKeys: String, CodingKey {
        case fileUuid = "file_uuid"
        case status
        case noteContentPreview = "note_content_preview"
        case mediaType = "media_type"
        case organizedNoteId = "organized_note_id"
        case title
        case categoryId = "category_id"
        case categoryName = "category_name"
        case error
    }
}

/// The wire statuses the contract defines. Anything else is treated as
/// `processing` (a no-op for the client) for forward compatibility.
enum NoteWireStatus: String, Sendable {
    case processing
    case transcribed
    case completed
    case failed
}

/// Pure server-wire → client-lifecycle mapping:
/// `processing` → uploaded (no-op), `transcribed` → transcribed (+preview),
/// `completed` → organized (+organizedNoteId/title/categoryName),
/// `failed` → failed, unknown → no-op.
enum NoteStatusMapping {
    /// The server silently caps `file_uuids` at 50 per request — anything
    /// past the cap is dropped from the response, so requests must be
    /// chunked or the oldest records starve.
    static let maxUuidsPerRequest = 50

    /// Splits `uuids` into request-sized chunks, preserving order.
    static func chunked(_ uuids: [String], size: Int = maxUuidsPerRequest) -> [[String]] {
        guard size > 0, !uuids.isEmpty else { return [] }
        return stride(from: 0, to: uuids.count, by: size).map { start in
            Array(uuids[start..<min(start + size, uuids.count)])
        }
    }

    /// Returns the record as it should look after applying `entry`.
    /// Terminal records are never changed (the poller only asks about
    /// non-terminal uuids; this guard is belt-and-braces), and a record is
    /// never downgraded — `processing` and unknown statuses leave it as-is.
    static func apply(_ entry: FileStatusEntry, to record: PendingNoteRecord) -> PendingNoteRecord {
        guard !record.isTerminal else { return record }

        var updated = record
        switch NoteWireStatus(rawValue: entry.status) {
        case .processing, nil:
            // Still in the pipeline (or a status this client doesn't know
            // about yet) — keep waiting.
            break
        case .transcribed:
            updated.lifecycleStatus = .transcribed
            if let preview = entry.noteContentPreview, !preview.isEmpty {
                updated.transcribedPreview = preview
            }
        case .completed:
            updated.lifecycleStatus = .organized
            updated.organizedNoteId = entry.organizedNoteId
            updated.title = entry.title
            updated.categoryName = entry.categoryName
        case .failed:
            updated.lifecycleStatus = .failed
            if let message = entry.error, !message.isEmpty {
                updated.errorMessage = message
            }
        }
        return updated
    }
}

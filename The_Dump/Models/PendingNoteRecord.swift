import Foundation

/// What the user captured, derived from the upload path that produced the record.
enum PendingNoteKind: String, Codable, Sendable {
    case text
    case voice
    case photo
    case file
}

/// Client-side lifecycle of a note as it moves through the processing pipeline.
/// Mirrors the server states in docs/note-status-contract.md:
/// `processing` → `uploaded`, `transcribed` → `transcribed`,
/// `completed` → `organized`, `failed` → `failed`.
/// Notes may skip `transcribed` and jump straight to `organized`.
enum PendingNoteLifecycleStatus: String, Codable, Sendable {
    case uploaded
    case transcribed
    case organized
    case failed

    var isTerminal: Bool {
        self == .organized || self == .failed
    }
}

/// One persisted record per successful upload, written when `UploadResponse`
/// returns. Tracked until the user acknowledges a terminal state or the
/// 24h contract TTL expires (the server-side manifest is pruned after 24h,
/// so older UUIDs can no longer be answered for).
struct PendingNoteRecord: Codable, Equatable, Identifiable, Sendable {
    /// Client-generated file UUID from `UploadResponse.uuid` — the identity
    /// chain key across processing_manifest, intake_notes and organized_notes.
    let fileUuid: String
    /// GCS object path from `UploadResponse.storagePath`.
    let storagePath: String
    let kind: PendingNoteKind
    let createdAt: Date
    /// Typed notes only — the content the user typed, shown immediately
    /// regardless of processing status.
    let localText: String?
    var lifecycleStatus: PendingNoteLifecycleStatus
    /// From the `transcribed` payload's `note_content_preview`.
    var transcribedPreview: String?
    /// From the `completed` payload.
    var organizedNoteId: String?
    var categoryName: String?
    var title: String?
    /// From the `failed` payload's `error` string. Optional + Codable, so
    /// records persisted before this field existed decode unchanged.
    var errorMessage: String?
    /// Set when the user acknowledges a terminal state; acknowledged
    /// terminal records are dropped on the next prune.
    var acknowledged: Bool

    var id: String { fileUuid }

    var isTerminal: Bool { lifecycleStatus.isTerminal }

    init(
        fileUuid: String,
        storagePath: String,
        kind: PendingNoteKind,
        createdAt: Date = Date(),
        localText: String? = nil,
        lifecycleStatus: PendingNoteLifecycleStatus = .uploaded,
        transcribedPreview: String? = nil,
        organizedNoteId: String? = nil,
        categoryName: String? = nil,
        title: String? = nil,
        errorMessage: String? = nil,
        acknowledged: Bool = false
    ) {
        self.fileUuid = fileUuid
        self.storagePath = storagePath
        self.kind = kind
        self.createdAt = createdAt
        self.localText = localText
        self.lifecycleStatus = lifecycleStatus
        self.transcribedPreview = transcribedPreview
        self.organizedNoteId = organizedNoteId
        self.categoryName = categoryName
        self.title = title
        self.errorMessage = errorMessage
        self.acknowledged = acknowledged
    }
}

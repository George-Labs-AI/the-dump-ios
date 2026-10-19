import Foundation

// How a note row in a list describes itself.
extension NotePreview {
    /// The sender of an emailed note, or nil for the owner's own notes (the
    /// server sends null, and a blank value means the same).
    var displayAuthor: String? {
        guard let trimmed = author?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// True for a row that stands for a whole stack in a list fetched with
    /// stacks=1. Same rule as the web: a stack id plus more than one note.
    /// A stack's members carry its id but no counts, so they stay plain notes.
    var isStack: Bool {
        guard let stack_id, !stack_id.isEmpty else { return false }
        return (stack_total ?? stack_size ?? 1) > 1
    }

    /// The row's identity in a list. A stack row carries its newest note's
    /// id, which changes when that note is deleted or a newer one joins, so
    /// the row is identified by its stack instead; otherwise reloading the
    /// list would replace the row and close a stack screen opened from it.
    var listRowID: String {
        if isStack, let stack_id { return "stack-\(stack_id)" }
        return organized_note_id
    }

    /// "5 notes", or "2 of 5 notes" when the list's filters match only some
    /// of the stack. Nil for a plain note.
    var stackLabel: String? {
        guard isStack else { return nil }
        let total = stack_total ?? stack_size ?? 1
        let matching = stack_size ?? total
        return matching < total ? "\(matching) of \(total) notes" : "\(total) notes"
    }
}

extension Array where Element == NotePreview {
    /// The rows a list keeps after the note `noteId` was deleted from its own
    /// screen. A row that stands for a stack carries its newest note's id,
    /// but the stack still holds its other notes, so that row stays until the
    /// list reloads.
    func removingDeletedNote(_ noteId: String) -> [NotePreview] {
        filter { $0.id != noteId || $0.isStack }
    }

    /// Whether the note `noteId` is the one a stack row stands for, so that
    /// deleting it means the list must reload to show the stack's next note.
    func hasStackRow(standingFor noteId: String) -> Bool {
        contains { $0.id == noteId && $0.isStack }
    }
}

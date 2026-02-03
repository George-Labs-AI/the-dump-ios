import Foundation
import Combine

@MainActor
final class NoteDetailViewModel: ObservableObject {
    @Published private(set) var note: NoteDetail?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isSaving: Bool = false
    @Published private(set) var errorMessage: String?
    
    private let noteID: String
    
    init(noteID: String) {
        self.noteID = noteID
    }
    
    func loadIfNeeded() async {
        guard note == nil else { return }
        await load()
    }
    
    func reload() async {
        note = nil
        await load()
    }
    
    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            let notes = try await NotesService.shared.fetchFullNote(ids: [noteID])
            note = notes.first
            if note == nil {
                errorMessage = "Note not found."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }

    func saveEdits(title: String, content: String) async -> Bool {
        guard let currentNote = note else {
            errorMessage = "No note loaded."
            return false
        }

        guard !isSaving else { return false }
        isSaving = true
        errorMessage = nil

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Title is required."
            isSaving = false
            return false
        }

        do {
            let updated = try await NotesService.shared.editNote(
                noteId: currentNote.organized_note_id,
                entries: content,
                title: trimmedTitle
            )

            note = NoteDetail(
                organized_note_id: updated.organized_note_id,
                title: updated.title ?? trimmedTitle,
                note_content: updated.note_content ?? content,
                note_content_modified: updated.note_content_modified ?? currentNote.note_content_modified,
                category_name: updated.category_name ?? currentNote.category_name,
                sub_cat_names: updated.sub_cat_names ?? currentNote.sub_cat_names,
                tags: currentNote.tags,
                mime_type: updated.mime_type ?? currentNote.mime_type,
                note_type: updated.note_type ?? currentNote.note_type
            )

            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }
}

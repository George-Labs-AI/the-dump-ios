import Foundation
import Combine

@MainActor
final class NoteDetailViewModel: ObservableObject {
    @Published private(set) var note: NoteDetail?
    @Published private(set) var isLoading: Bool = false
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
}

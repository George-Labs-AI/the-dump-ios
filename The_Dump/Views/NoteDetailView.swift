import SwiftUI
import Combine

struct NoteDetailView: View {
    private let noteID: String
    @StateObject private var viewModel: NoteDetailViewModel
    
    init(noteID: String) {
        self.noteID = noteID
        _viewModel = StateObject(wrappedValue: NoteDetailViewModel(noteID: noteID))
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            Group {
                if viewModel.isLoading && viewModel.note == nil {
                    ProgressView("Loading…")
                        .foregroundColor(Theme.textPrimary)
                } else if let error = viewModel.errorMessage, viewModel.note == nil {
                    VStack(spacing: Theme.spacingMD) {
                        Text(error)
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.accent)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            Task { await viewModel.reload() }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(Theme.spacingLG)
                } else if let note = viewModel.note {
                    ScrollView {
                        Text(note.note_content)
                            .font(.system(size: Theme.fontSizeMD))
                            .foregroundColor(Theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Theme.spacingLG)
                    }
                } else {
                    Text("No content.")
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .navigationTitle("Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await viewModel.loadIfNeeded()
        }
    }
}

#Preview {
    NavigationStack {
        NoteDetailView(noteID: "example-id")
    }
}



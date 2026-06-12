import SwiftUI

struct TextNoteView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var noteContent: String = ""
    @State private var isUploading = false
    @State private var uploadError: String?

    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Text editor
                    TextEditor(text: $noteContent)
                        .focused($isTextEditorFocused)
                        .scrollContentBackground(.hidden)
                        .background(Theme.surface)
                        .foregroundColor(Theme.textPrimary)
                        .font(.system(size: Theme.fontSizeMD))
                        .cornerRadius(Theme.cornerRadius)
                        .padding(.horizontal, Theme.spacingMD)
                        .padding(.top, Theme.spacingMD)

                    // Footer with character count and error
                    VStack(spacing: Theme.spacingSM) {
                        if let error = uploadError {
                            Text(error)
                                .font(.system(size: Theme.fontSizeSM))
                                .foregroundColor(Theme.accent)
                        }

                        HStack {
                            Text("\(noteContent.count) characters")
                                .font(.system(size: Theme.fontSizeXS))
                                .foregroundColor(Theme.textSecondary)

                            Spacer()

                            Button(action: uploadNote) {
                                HStack(spacing: Theme.spacingSM) {
                                    if isUploading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.textPrimary))
                                            .scaleEffect(0.8)
                                    }
                                    Text(isUploading ? "Uploading..." : "Upload")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle(isEnabled: canUpload))
                            .disabled(!canUpload)
                        }
                    }
                    .padding(.horizontal, Theme.spacingMD)
                    .padding(.vertical, Theme.spacingMD)
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.textPrimary)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            isTextEditorFocused = true
        }
    }

    private var canUpload: Bool {
        !isUploading && !noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func uploadNote() {
        Task {
            guard let idToken = await appState.idToken else {
                uploadError = "Not authenticated"
                return
            }

            isUploading = true
            uploadError = nil

            let item = SessionItem(
                kind: .text,
                originalFilename: "note_\(UUID().uuidString.prefix(8)).txt",
                status: .uploading
            )
            sessionStore.addItem(item)

            do {
                _ = try await UploadService.shared.uploadTextNote(
                    content: noteContent,
                    idToken: idToken
                )
                // The PendingNoteRecord is added before uploadTextNote
                // returns — the Processing row on the capture screen takes
                // over, so drop the transient session row instead of
                // overlapping it with "Captured!".
                sessionStore.removeItem(id: item.id)
                dismiss()
            } catch {
                sessionStore.markFailed(id: item.id, error: error.localizedDescription)
                uploadError = error.localizedDescription
            }

            isUploading = false
        }
    }
}

#Preview {
    TextNoteView()
        .environmentObject(AppState())
        .environmentObject(SessionStore())
}

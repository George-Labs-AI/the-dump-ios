import SwiftUI

// The notes in one stack, opened from a stack row in a notes list. Tapping a
// note opens it; Unstack turns the stack back into ordinary notes.

struct StackDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: StackDetailViewModel
    @State private var showUnstackConfirmation = false

    /// Called after the stack changed (unstacked, or found gone), so the list
    /// behind this screen reloads.
    private let onChanged: () -> Void

    init(stackId: String, onChanged: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: StackDetailViewModel(stackId: stackId))
        self.onChanged = onChanged
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            Group {
                if viewModel.isLoading && viewModel.notes.isEmpty && !viewModel.isGone {
                    ProgressView("Loading…")
                        .foregroundColor(Theme.textPrimary)
                } else if viewModel.isGone {
                    Text("This stack has been unstacked. Its notes are back in your lists.")
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(Theme.spacingLG)
                } else if let error = viewModel.errorMessage, viewModel.notes.isEmpty {
                    VStack(spacing: Theme.spacingMD) {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textPrimary)
                            .multilineTextAlignment(.center)

                        Button("Retry") {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(Theme.spacingLG)
                } else {
                    List {
                        Section {
                            if let error = viewModel.errorMessage {
                                Label(error, systemImage: "exclamationmark.circle")
                                    .font(.system(size: Theme.fontSizeSM))
                                    .foregroundColor(Theme.textPrimary)
                                    .listRowBackground(Theme.surface)
                            }

                            ForEach(viewModel.notes) { note in
                                NavigationLink {
                                    NoteDetailView(noteID: note.id, backTitle: "Stack")
                                } label: {
                                    NoteListRowView(note: note)
                                }
                                .listRowBackground(Theme.surface)
                            }
                        } header: {
                            Text("\(viewModel.notes.count) notes in this stack")
                                .sectionLabel()
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.load()
                    }
                }
            }
        }
        .navigationTitle(viewModel.title.flatMap { $0.isEmpty ? nil : $0 } ?? "Stack")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if !viewModel.isGone {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Unstack") {
                        showUnstackConfirmation = true
                    }
                    .disabled(viewModel.isUnstacking || viewModel.notes.isEmpty)
                }
            }
        }
        // Reload each time the screen shows again, so a note deleted or
        // changed from its own screen is reflected here, and tell the list
        // behind when the stack lost notes or is gone (its row may have
        // stood for a note that was just deleted).
        .onAppear {
            Task {
                let before = viewModel.notes.map(\.id)
                await viewModel.load()
                let after = viewModel.notes.map(\.id)
                if viewModel.isGone || (!before.isEmpty && before != after) {
                    onChanged()
                }
            }
        }
        .alert("Unstack these notes?", isPresented: $showUnstackConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Unstack") {
                Task {
                    if await viewModel.unstack() {
                        onChanged()
                        dismiss()
                    }
                }
            }
        } message: {
            Text("The \(viewModel.notes.count) notes stay as they are and show up one by one in your lists again.")
        }
    }
}

#Preview {
    NavigationStack {
        StackDetailView(stackId: "00000000-0000-0000-0000-000000000000", onChanged: {})
    }
}

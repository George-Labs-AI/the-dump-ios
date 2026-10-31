import Foundation
import SwiftUI
import Combine

@MainActor
class SessionStore: ObservableObject {
    @Published var items: [SessionItem] = []

    private let autoRemoveDelay: Duration = .seconds(8)

    func addItem(_ item: SessionItem) {
        withAnimation { items.insert(item, at: 0) }
    }

    func updateStatus(id: String, status: UploadStatus) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = status
    }

    /// Upload progress arrives many times a second; only steps of 2% or
    /// more (and the finish) are published, so the list isn't redrawn for
    /// every packet.
    func updateProgress(id: String, progress: Double) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let previous = items[index].progress ?? 0
        guard progress >= 1 || progress - previous >= 0.02 else { return }
        items[index].progress = progress
    }

    func markUploading(id: String) {
        updateStatus(id: id, status: .uploading)
    }

    func markCaptured(id: String) {
        withAnimation {
            updateStatus(id: id, status: .captured)
        }
        scheduleAutoRemoval(id: id)
    }

    func markFailed(id: String, error: String) {
        updateStatus(id: id, status: .failed(error: error))
    }

    /// Remove a single item immediately. Upload success paths use this so
    /// the transient session row hands off to the persistent Processing row
    /// (PendingNotesStore) without the two overlapping.
    func removeItem(id: String) {
        withAnimation {
            items.removeAll { $0.id == id }
        }
    }

    func getItem(id: String) -> SessionItem? {
        items.first { $0.id == id }
    }

    func clear() {
        items.removeAll()
    }

    private func scheduleAutoRemoval(id: String) {
        Task {
            try? await Task.sleep(for: autoRemoveDelay)
            guard !Task.isCancelled else { return }
            withAnimation {
                items.removeAll { $0.id == id }
            }
        }
    }
}

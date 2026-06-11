import Foundation
import Combine

/// MainActor mirror of the actor-based `PendingNotesStore` so SwiftUI can
/// observe it (the store itself is an actor and can't be observed directly).
/// Refreshes whenever the store posts `.pendingNotesStoreDidChange` — i.e.
/// after every persisted mutation (new upload, status poll update,
/// acknowledge, prune).
@MainActor
final class PendingNotesViewModel: ObservableObject {
    /// Unacknowledged records, newest first. Acknowledged terminal records
    /// are hidden here immediately; the store drops them on the next prune.
    @Published private(set) var records: [PendingNoteRecord] = []

    private let store: PendingNotesStore
    private var changeObserver: NSObjectProtocol?

    init(store: PendingNotesStore = .shared) {
        self.store = store

        changeObserver = NotificationCenter.default.addObserver(
            forName: .pendingNotesStoreDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }

        Task { [weak self] in
            await self?.refresh()
        }
    }

    deinit {
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
    }

    func refresh() async {
        records = await store.allRecords().filter { !$0.acknowledged }
    }

    /// Acknowledge a terminal record (organized tap / failed dismiss):
    /// hides it from the section right away and persists the flag.
    func acknowledge(fileUuid: String) {
        records.removeAll { $0.fileUuid == fileUuid }
        Task { [store] in
            await store.acknowledge(fileUuid: fileUuid)
        }
    }
}

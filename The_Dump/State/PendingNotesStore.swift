import Foundation

/// Persisted store of in-flight note uploads (docs/note-status-contract.md,
/// Phase 1). One record per successful upload; survives app relaunch so the
/// status poller can resume after the app is killed.
///
/// Persistence matches the existing app pattern (CategoryRecategorizationTracker):
/// JSON-encoded `Codable` blob in `UserDefaults`. An actor serializes access
/// from concurrent async upload completions.
actor PendingNotesStore {
    static let shared = PendingNotesStore()

    /// Contract TTL — after 24h the server-side manifest is pruned and can
    /// no longer answer for a uuid, so the record is dropped.
    static let timeToLive: TimeInterval = 24 * 60 * 60

    private let defaults: UserDefaults
    private let storageKey: String
    private var recordsByUuid: [String: PendingNoteRecord] = [:]
    private var hasLoadedPersistedRecords = false

    init(defaults: UserDefaults = .standard, storageKey: String = "pendingNoteRecords.v1") {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    // MARK: - Mutations

    /// Insert (or replace, by uuid) a record. Called from upload completions.
    func add(_ record: PendingNoteRecord) {
        loadPersistedRecordsIfNeeded()
        recordsByUuid[record.fileUuid] = record
        persist()
    }

    /// Mutate an existing record in place; no-op if the uuid is unknown.
    func update(fileUuid: String, _ mutation: @Sendable (inout PendingNoteRecord) -> Void) {
        loadPersistedRecordsIfNeeded()
        guard var record = recordsByUuid[fileUuid] else { return }
        mutation(&record)
        recordsByUuid[fileUuid] = record
        persist()
    }

    /// Mark a terminal record as acknowledged by the user; it is dropped on
    /// the next prune.
    func acknowledge(fileUuid: String) {
        update(fileUuid: fileUuid) { $0.acknowledged = true }
    }

    func remove(fileUuid: String) {
        loadPersistedRecordsIfNeeded()
        guard recordsByUuid.removeValue(forKey: fileUuid) != nil else { return }
        persist()
    }

    /// Drops records older than the 24h contract TTL and acknowledged
    /// terminal records. Call on app launch.
    func prune(now: Date = Date()) {
        loadPersistedRecordsIfNeeded()
        let cutoff = now.addingTimeInterval(-Self.timeToLive)
        let kept = recordsByUuid.filter { _, record in
            record.createdAt > cutoff && !(record.isTerminal && record.acknowledged)
        }
        guard kept.count != recordsByUuid.count else { return }
        recordsByUuid = kept
        persist()
    }

    // MARK: - Queries

    /// All stored records, newest first.
    func allRecords() -> [PendingNoteRecord] {
        loadPersistedRecordsIfNeeded()
        return recordsByUuid.values.sorted { $0.createdAt > $1.createdAt }
    }

    /// Records still moving through the pipeline (not organized/failed),
    /// newest first — the set the status poller asks the server about.
    func nonTerminalRecords() -> [PendingNoteRecord] {
        allRecords().filter { !$0.isTerminal }
    }

    func record(fileUuid: String) -> PendingNoteRecord? {
        loadPersistedRecordsIfNeeded()
        return recordsByUuid[fileUuid]
    }

    // MARK: - Persistence

    private func loadPersistedRecordsIfNeeded() {
        guard !hasLoadedPersistedRecords else { return }
        hasLoadedPersistedRecords = true

        guard let data = defaults.data(forKey: storageKey) else { return }

        do {
            let decoded = try JSONDecoder().decode([PendingNoteRecord].self, from: data)
            recordsByUuid = Dictionary(uniqueKeysWithValues: decoded.map { ($0.fileUuid, $0) })
        } catch {
            defaults.removeObject(forKey: storageKey)
            recordsByUuid = [:]
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(Array(recordsByUuid.values))
            defaults.set(data, forKey: storageKey)
        } catch {
            #if DEBUG
            print("[PendingNotesStore] Failed to persist records: \(error)")
            #endif
        }
    }
}

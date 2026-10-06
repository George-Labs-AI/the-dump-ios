import Foundation

extension Notification.Name {
    /// Posted after any persisted mutation of the pending-note records
    /// (add / update / acknowledge / remove / prune). Observed by
    /// `PendingNotesViewModel` to mirror the actor's state for SwiftUI.
    nonisolated static let pendingNotesStoreDidChange = Notification.Name("pendingNotesStoreDidChange")
}

/// Persisted store of in-flight note uploads (docs/note-status-contract.md,
/// Phase 1). One record per successful upload; survives app relaunch so the
/// status poller can resume after the app is killed.
///
/// Persistence matches the existing app pattern (CategoryRecategorizationTracker):
/// JSON-encoded `Codable` blob in `UserDefaults`. An actor serializes access
/// from concurrent async upload completions.
///
/// The blob lives in the App Group suite so the share extension, which runs
/// as a separate process, can add records for its own uploads and the main
/// app shows them in Processing like any other capture. Each process caches
/// the records in memory after its first load, so the main app must call
/// `reload()` when it comes to the foreground — before `prune()` or any other
/// mutation — or it would persist its stale copy over what the extension
/// wrote. On iPhone the two processes never run at the same time (the share
/// sheet backgrounds the app, which suspends polling), so last-writer-wins
/// on the blob is acceptable. Known limit: in iPad Split View the app can
/// stay active while another app shares into the extension; no scene-phase
/// change fires, so the record only shows after the next foregrounding.
actor PendingNotesStore {
    static let shared = PendingNotesStore()

    /// Contract TTL — after 24h the server-side manifest is pruned and can
    /// no longer answer for a uuid, so the record is dropped.
    static let timeToLive: TimeInterval = 24 * 60 * 60

    private let defaults: UserDefaults
    /// Where releases up to 2.3 kept the records (the main app's standard
    /// defaults). Migrated into `defaults` once, on first load, so in-flight
    /// records survive the upgrade. `nil` disables migration.
    private let legacyDefaults: UserDefaults?
    private let storageKey: String
    private var recordsByUuid: [String: PendingNoteRecord] = [:]
    private var hasLoadedPersistedRecords = false

    /// - Parameters:
    ///   - defaults: Suite to persist in. Defaults to the App Group suite
    ///     shared with the extension, falling back to standard defaults if
    ///     the suite can't be opened (missing entitlement).
    ///   - legacyDefaults: Pre-App-Group location to migrate from, once.
    ///   - storageKey: Key for the JSON blob.
    init(
        defaults: UserDefaults? = UserDefaults(suiteName: SharedConstants.appGroupID),
        legacyDefaults: UserDefaults? = .standard,
        storageKey: String = SharedConstants.pendingNoteRecordsKey
    ) {
        self.defaults = defaults ?? .standard
        self.legacyDefaults = legacyDefaults
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

    /// Re-reads the persisted records, replacing the in-memory copy, and
    /// posts `.pendingNotesStoreDidChange` if anything differed. Call on
    /// every foregrounding, before `prune()` or any other mutation, to pick
    /// up records the share extension wrote while this process was
    /// suspended.
    func reload() {
        let before = recordsByUuid
        hasLoadedPersistedRecords = false
        recordsByUuid = [:]
        loadPersistedRecordsIfNeeded()
        if recordsByUuid != before {
            NotificationCenter.default.post(name: .pendingNotesStoreDidChange, object: nil)
        }
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

        recordsByUuid = decodeRecords(from: defaults)
        migrateLegacyRecordsIfNeeded()
    }

    /// One-time move from the pre-App-Group location. Merged by uuid rather
    /// than copied wholesale: the share extension may already have written
    /// to the shared suite (first share after the upgrade, before the app
    /// was opened), and those records must not hide the ones still in the
    /// old location. Shared-suite records win on a uuid clash.
    private func migrateLegacyRecordsIfNeeded() {
        guard let legacyDefaults,
              legacyDefaults !== defaults,
              legacyDefaults.data(forKey: storageKey) != nil else { return }
        let legacy = decodeRecords(from: legacyDefaults)
        legacyDefaults.removeObject(forKey: storageKey)
        guard !legacy.isEmpty else { return }
        recordsByUuid.merge(legacy) { shared, _ in shared }
        persist()
    }

    /// Decodes the stored blob; an undecodable blob is dropped so one bad
    /// write can't wedge the store forever.
    private func decodeRecords(from source: UserDefaults) -> [String: PendingNoteRecord] {
        guard let data = source.data(forKey: storageKey) else { return [:] }
        do {
            let decoded = try JSONDecoder().decode([PendingNoteRecord].self, from: data)
            return Dictionary(uniqueKeysWithValues: decoded.map { ($0.fileUuid, $0) })
        } catch {
            source.removeObject(forKey: storageKey)
            return [:]
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(Array(recordsByUuid.values))
            defaults.set(data, forKey: storageKey)
            NotificationCenter.default.post(name: .pendingNotesStoreDidChange, object: nil)
        } catch {
            #if DEBUG
            print("[PendingNotesStore] Failed to persist records: \(error)")
            #endif
        }
    }
}

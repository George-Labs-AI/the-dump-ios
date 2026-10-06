import XCTest
@testable import The_Dump

/// `PendingNotesStore` lives in Shared/ and is compiled into both the app and
/// the share extension. These tests cover the cross-process contract: the
/// extension adds records to the App Group suite while the app is suspended,
/// and the app must see them when it reloads on foregrounding.
final class PendingNotesStoreTests: XCTestCase {

    private var suiteName: String!
    private var legacySuiteName: String!
    private var defaults: UserDefaults!
    private var legacyDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.pendingnotes.\(UUID().uuidString)"
        legacySuiteName = "test.pendingnotes.legacy.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        legacyDefaults = UserDefaults(suiteName: legacySuiteName)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        UserDefaults.standard.removePersistentDomain(forName: legacySuiteName)
        defaults = nil
        legacyDefaults = nil
        super.tearDown()
    }

    private func makeStore(legacy: UserDefaults? = nil) -> PendingNotesStore {
        PendingNotesStore(defaults: defaults, legacyDefaults: legacy)
    }

    private func makeRecord(_ uuid: String, kind: PendingNoteKind = .photo) -> PendingNoteRecord {
        PendingNoteRecord(fileUuid: uuid, storagePath: "uploads/u/\(uuid).jpg", kind: kind)
    }

    // MARK: - Persistence

    func test_add_isVisibleToAFreshInstanceOnTheSameSuite() async {
        let writer = makeStore()
        await writer.add(makeRecord("a"))

        let reader = makeStore()
        let records = await reader.allRecords()
        XCTAssertEqual(records.map(\.fileUuid), ["a"])
    }

    // MARK: - Cross-process reload (share extension → main app)

    func test_reload_picksUpRecordWrittenByAnotherInstance() async {
        let app = makeStore()
        _ = await app.allRecords()                 // app loads (empty) and caches

        let ext = makeStore()                       // the extension process
        await ext.add(makeRecord("from-extension"))

        let stale = await app.allRecords()
        XCTAssertTrue(stale.isEmpty, "cached copy is stale until reload")

        await app.reload()
        let fresh = await app.allRecords()
        XCTAssertEqual(fresh.map(\.fileUuid), ["from-extension"])
    }

    func test_reloadThenPrune_keepsExtensionRecord() async {
        let app = makeStore()
        await app.add(makeRecord("old"))

        let ext = makeStore()
        await ext.add(makeRecord("new"))

        // The foregrounding sequence NoteStatusService runs: reload, then prune.
        await app.reload()
        await app.prune()

        let ids = await app.allRecords().map(\.fileUuid).sorted()
        XCTAssertEqual(ids, ["new", "old"])

        // And the blob on disk still has both (prune did not clobber it).
        let onDisk = makeStore()
        let diskIds = await onDisk.allRecords().map(\.fileUuid).sorted()
        XCTAssertEqual(diskIds, ["new", "old"])
    }

    func test_pruneWithoutReload_wouldClobberExtensionRecord() async {
        // Documents why reload() must come first: a prune from the stale cache
        // that drops anything persists the stale array.
        let app = makeStore()
        await app.add(PendingNoteRecord(
            fileUuid: "expired",
            storagePath: "p",
            kind: .photo,
            createdAt: Date().addingTimeInterval(-PendingNotesStore.timeToLive - 60)
        ))

        let ext = makeStore()
        await ext.add(makeRecord("new"))

        await app.prune()                           // no reload first

        let onDisk = makeStore()
        let diskIds = await onDisk.allRecords().map(\.fileUuid)
        XCTAssertTrue(diskIds.isEmpty, "stale prune overwrote the extension's record — this is the bug reload() prevents")
    }

    func test_reload_postsChangeNotificationOnlyWhenSomethingChanged() async {
        let app = makeStore()
        await app.add(makeRecord("a"))

        let unchanged = expectation(forNotification: .pendingNotesStoreDidChange, object: nil)
        unchanged.isInverted = true
        await app.reload()
        await fulfillment(of: [unchanged], timeout: 0.2)

        let ext = makeStore()
        await ext.add(makeRecord("b"))

        let changed = expectation(forNotification: .pendingNotesStoreDidChange, object: nil)
        await app.reload()
        await fulfillment(of: [changed], timeout: 1)
    }

    // MARK: - Migration from the pre-App-Group location

    func test_firstLoad_migratesLegacyRecordsIntoSharedSuiteOnce() async throws {
        let legacy = try XCTUnwrap(legacyDefaults)
        let legacyStore = PendingNotesStore(defaults: legacy, legacyDefaults: nil)
        await legacyStore.add(makeRecord("legacy-1"))
        await legacyStore.add(makeRecord("legacy-2"))

        let store = makeStore(legacy: legacy)
        let ids = await store.allRecords().map(\.fileUuid).sorted()
        XCTAssertEqual(ids, ["legacy-1", "legacy-2"])

        XCTAssertNotNil(defaults.data(forKey: SharedConstants.pendingNoteRecordsKey), "moved into the shared suite")
        XCTAssertNil(legacy.data(forKey: SharedConstants.pendingNoteRecordsKey), "removed from the legacy suite")
    }

    func test_firstLoad_mergesLegacyRecordsWhenExtensionWroteFirst() async throws {
        // Upgrade, then share a photo before opening the app: the extension
        // has already written to the shared suite. The app's old records
        // must still come across, and a uuid clash keeps the shared copy.
        let legacy = try XCTUnwrap(legacyDefaults)
        let legacyStore = PendingNotesStore(defaults: legacy, legacyDefaults: nil)
        await legacyStore.add(makeRecord("legacy"))
        await legacyStore.add(makeRecord("both", kind: .text))

        let ext = makeStore()
        await ext.add(makeRecord("shared"))
        await ext.add(makeRecord("both", kind: .photo))

        let app = makeStore(legacy: legacy)
        let records = await app.allRecords()
        XCTAssertEqual(records.map(\.fileUuid).sorted(), ["both", "legacy", "shared"])
        XCTAssertEqual(records.first { $0.fileUuid == "both" }?.kind, .photo, "shared-suite copy wins")
        XCTAssertNil(legacy.data(forKey: SharedConstants.pendingNoteRecordsKey), "legacy key removed after merge")

        let onDisk = makeStore()
        let diskIds = await onDisk.allRecords().map(\.fileUuid).sorted()
        XCTAssertEqual(diskIds, ["both", "legacy", "shared"], "merge persisted to the shared suite")
    }
}

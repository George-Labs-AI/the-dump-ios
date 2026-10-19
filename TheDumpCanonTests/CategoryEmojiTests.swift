import XCTest
@testable import The_Dump

/// A category's emoji is saved on the server: the request bodies that change
/// it, the replies that carry it, the input rules that match the server's,
/// and the one-time move of emoji chosen on this phone before that. Every
/// test is async on purpose: releasing a main-actor object at the end of a
/// synchronous test crashes under Xcode 26.
@MainActor
final class CategoryEmojiTests: XCTestCase {
    private struct NetworkDown: Error {}

    private var defaults: UserDefaults!
    private var suiteName = ""

    override func setUp() async throws {
        suiteName = "CategoryEmojiTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// One category as the server lists it. `emoji` is pasted into the JSON
    /// as written, so pass `"null"` for null and nil to leave the key out.
    private func category(id: Int, emoji: String? = "null", archived: Bool = false) throws -> CategoryResponse {
        let emojiPart = emoji.map { ", \"emoji\": \($0)" } ?? ""
        let json = """
        {"category_id": \(id), "name": "Category \(id)", "definition": "", "keywords": [],
         "source": "user", "date_added": "2026-10-01", "last_modified_date": "2026-10-01",
         "archived": \(archived)\(emojiPart)}
        """
        return try JSONDecoder().decode(CategoryResponse.self, from: Data(json.utf8))
    }

    private func store() -> CategoryEmojiStore {
        CategoryEmojiStore(defaults: defaults)
    }

    // MARK: - PATCH /api/categories/<id> bodies

    func testEmojiOnlyChangeSendsOnlyTheEmoji() async throws {
        let body = try jsonObject(CategoryUpdateRequest(emoji: "🍕"))
        XCTAssertEqual(body["emoji"] as? String, "🍕")
        XCTAssertEqual(body.count, 1)
    }

    func testEmojiTravelsWithOtherChanges() async throws {
        let body = try jsonObject(CategoryUpdateRequest(
            categoryName: "Recipes",
            keywords: ["pasta"],
            emoji: "🍝"
        ))
        XCTAssertEqual(body["category_name"] as? String, "Recipes")
        XCTAssertEqual(body["keywords"] as? [String], ["pasta"])
        XCTAssertEqual(body["emoji"] as? String, "🍝")
        XCTAssertNil(body["category_description"])
        XCTAssertEqual(body.count, 3)
    }

    func testClearingSendsAnEmptyEmoji() async throws {
        let body = try jsonObject(CategoryUpdateRequest(emoji: ""))
        XCTAssertEqual(body["emoji"] as? String, "")
        XCTAssertEqual(body.count, 1)
    }

    func testAnUnchangedEmojiIsLeftOut() async throws {
        let body = try jsonObject(CategoryUpdateRequest(categoryName: "Recipes"))
        XCTAssertNil(body["emoji"])
        XCTAssertEqual(body.count, 1)
    }

    // MARK: - Replies

    func testCategoryListDecodesEmojiPresentNullOrAbsent() async throws {
        let present = try category(id: 1, emoji: "\"🍕\"")
        XCTAssertEqual(present.emoji, "🍕")
        XCTAssertTrue(present.sendsEmoji)

        let null = try category(id: 2, emoji: "null")
        XCTAssertNil(null.emoji)
        XCTAssertTrue(null.sendsEmoji)

        // A server from before emoji were saved leaves the key out.
        let absent = try category(id: 3, emoji: nil)
        XCTAssertNil(absent.emoji)
        XCTAssertFalse(absent.sendsEmoji)
        XCTAssertEqual(absent.name, "Category 3")
        XCTAssertEqual(absent.archived, false)
    }

    func testListItemShowsTheFolderWithoutAnEmoji() async throws {
        let withEmoji = CategoryListItem.make(from: try category(id: 1, emoji: "\"🍕\""), noteCount: 0)
        XCTAssertEqual(withEmoji.displayEmoji, "🍕")
        let without = CategoryListItem.make(from: try category(id: 2, emoji: "null"), noteCount: 0)
        XCTAssertNil(without.emoji)
        XCTAssertEqual(without.displayEmoji, "📁")
        XCTAssertEqual(CategoryEmoji.displayed(""), "📁")
    }

    func testSaveReplyDecodesEmojiPresentNullOrAbsent() async throws {
        func decode(_ emojiPart: String) throws -> UpdatedCategory {
            let json = """
            {"status": "success", "category": {"category_id": 7, "category_name": "Recipes",
             "category_description": "", "keywords": [], "embedding_refreshed": false\(emojiPart)}}
            """
            return try JSONDecoder().decode(UpdatedCategoryResponse.self, from: Data(json.utf8)).category
        }
        XCTAssertEqual(try decode(", \"emoji\": \"🍕\"").emoji, "🍕")
        XCTAssertNil(try decode(", \"emoji\": null").emoji)
        XCTAssertNil(try decode("").emoji)
    }

    // MARK: - Input rules (the server's)

    func testValidationMatchesTheServer() async throws {
        XCTAssertEqual(CategoryEmoji.validated("🍕"), "🍕")
        XCTAssertEqual(CategoryEmoji.validated("  🍕\n"), "🍕", "spaces around it are trimmed")
        XCTAssertNil(CategoryEmoji.validated(""))
        XCTAssertNil(CategoryEmoji.validated("   "))
        XCTAssertNil(CategoryEmoji.validated("a"), "plain ASCII is refused")
        XCTAssertNil(CategoryEmoji.validated("7"))
        XCTAssertNil(CategoryEmoji.validated("🍕 🍝"), "no spaces inside")
        XCTAssertNil(CategoryEmoji.validated("🍕\u{0}"), "no control characters")
        XCTAssertNil(CategoryEmoji.validated("\u{80}"), "not even outside ASCII")

        // One emoji can be several code points; up to 16 are accepted.
        let family = "👨‍👩‍👧‍👦"
        XCTAssertEqual(family.unicodeScalars.count, 7)
        XCTAssertEqual(CategoryEmoji.validated(family), family)
        let longest = String(repeating: "🍕", count: 16)
        XCTAssertEqual(CategoryEmoji.validated(longest), longest)
        XCTAssertNil(CategoryEmoji.validated(longest + "🍕"))
        // A letter carrying many accent marks is one character on screen but
        // too many code points for the server.
        XCTAssertNil(CategoryEmoji.validated("e" + String(repeating: "\u{0301}", count: 16)))
    }

    func testFieldKeepsOneEmojiTheServerAccepts() async throws {
        // A new emoji replaces the old one.
        XCTAssertEqual(CategoryEmoji.fieldValue(previous: "📁", edited: "📁🍕"), "🍕")
        XCTAssertEqual(CategoryEmoji.fieldValue(previous: "", edited: "🍕"), "🍕")
        // Typing the same emoji again leaves one.
        XCTAssertEqual(CategoryEmoji.fieldValue(previous: "🍕", edited: "🍕🍕"), "🍕")
        // A letter, a digit or a space is undone.
        XCTAssertEqual(CategoryEmoji.fieldValue(previous: "📁", edited: "📁a"), "📁")
        XCTAssertEqual(CategoryEmoji.fieldValue(previous: "🍕", edited: "🍕7"), "🍕")
        XCTAssertEqual(CategoryEmoji.fieldValue(previous: "🍕", edited: "🍕 "), "🍕")
        XCTAssertEqual(CategoryEmoji.fieldValue(previous: "", edited: "a"), "")
        // Emptying the field means no emoji.
        XCTAssertEqual(CategoryEmoji.fieldValue(previous: "🍕", edited: ""), "")
        XCTAssertEqual(CategoryEmoji.fieldValue(previous: "🍕", edited: " "), "")
        // A skin-tone emoji is one character and is kept whole.
        XCTAssertEqual(CategoryEmoji.fieldValue(previous: "📁", edited: "📁👍🏽"), "👍🏽")
    }

    // MARK: - Moving emoji chosen on this phone (decision)

    private func server(_ id: Int, emoji: String? = nil, archived: Bool = false) -> CategoryEmojiMove.ServerCategory {
        CategoryEmojiMove.ServerCategory(id: id, emoji: emoji, archived: archived)
    }

    func testPhoneEmojiIsSentWhenTheServerHasNone() async throws {
        let plan = CategoryEmojiMove.plan(local: [1: "🍕"], server: [server(1)])
        XCTAssertEqual(plan.send, [1: "🍕"])
        XCTAssertTrue(plan.drop.isEmpty)
    }

    func testServerEmojiWinsAndThePhoneEmojiIsDropped() async throws {
        let plan = CategoryEmojiMove.plan(local: [1: "🍕"], server: [server(1, emoji: "🍝")])
        XCTAssertTrue(plan.send.isEmpty)
        XCTAssertEqual(plan.drop, [1])
    }

    func testTheFolderDefaultIsNeverSent() async throws {
        let plan = CategoryEmojiMove.plan(local: [1: "📁", 2: " 📁 "], server: [server(1), server(2)])
        XCTAssertTrue(plan.send.isEmpty)
        XCTAssertEqual(plan.drop, [1, 2])
    }

    func testAnEmojiTheServerWouldRefuseIsDropped() async throws {
        // The old field let a single letter through.
        let plan = CategoryEmojiMove.plan(local: [1: "a", 2: ""], server: [server(1), server(2)])
        XCTAssertTrue(plan.send.isEmpty)
        XCTAssertEqual(plan.drop, [1, 2])
    }

    func testArchivedAndUnknownCategoriesAreLeftOnThePhone() async throws {
        let plan = CategoryEmojiMove.plan(
            local: [1: "🍕", 2: "🍝"],
            server: [server(1, archived: true)]
        )
        XCTAssertTrue(plan.send.isEmpty)
        XCTAssertTrue(plan.drop.isEmpty)
    }

    func testPhoneEmojiIsTrimmedBeforeSending() async throws {
        let plan = CategoryEmojiMove.plan(local: [1: " 🍕 "], server: [server(1)])
        XCTAssertEqual(plan.send, [1: "🍕"])
    }

    // MARK: - Moving emoji chosen on this phone (store and sending)

    func testStoreDeletesItsKeyOnceEmpty() async throws {
        let store = store()
        store.set("🍕", for: 1)
        store.set("🍝", for: 2)
        XCTAssertEqual(store.entries, [1: "🍕", 2: "🍝"])
        store.remove(1)
        XCTAssertEqual(store.entries, [2: "🍝"])
        XCTAssertNotNil(defaults.object(forKey: CategoryEmojiStore.key))
        store.remove(2)
        XCTAssertNil(defaults.object(forKey: CategoryEmojiStore.key))
    }

    func testStoreReadsWhatEarlierVersionsSaved() async throws {
        defaults.set(["12": "🍕", "13": "📁"], forKey: "categoryEmojis.v1")
        XCTAssertEqual(store().entries, [12: "🍕", 13: "📁"])
    }

    func testSuccessfulMoveForgetsEachEmojiAndThenTheKey() async throws {
        let store = store()
        store.set("🍕", for: 1)
        store.set("🍝", for: 2)
        store.set("📁", for: 3)
        store.set("🥗", for: 4)
        var sent: [Int: String] = [:]
        let mover = CategoryEmojiMover(store: store) { categoryId, emoji in
            sent[categoryId] = emoji
        }

        let moved = await mover.run(categories: [
            try category(id: 1),
            try category(id: 2),
            try category(id: 3),
            try category(id: 4, emoji: "\"🍔\"")
        ])

        XCTAssertEqual(sent, [1: "🍕", 2: "🍝"])
        XCTAssertEqual(moved, [1: "🍕", 2: "🍝"])
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertNil(defaults.object(forKey: CategoryEmojiStore.key))
    }

    func testFailedSendKeepsTheEmojiForALaterLoad() async throws {
        let store = store()
        store.set("🍕", for: 1)
        store.set("🍝", for: 2)
        let mover = CategoryEmojiMover(store: store) { categoryId, _ in
            if categoryId == 1 { throw NetworkDown() }
        }

        let moved = await mover.run(categories: [try category(id: 1), try category(id: 2)])

        XCTAssertEqual(moved, [2: "🍝"])
        XCTAssertEqual(store.entries, [1: "🍕"])
    }

    func testRefusedEmojiIsForgotten() async throws {
        let store = store()
        store.set("🍕", for: 1)
        let mover = CategoryEmojiMover(store: store) { _, _ in
            throw APIError.badRequest(message: "Pick a single emoji.")
        }

        let moved = await mover.run(categories: [try category(id: 1)])

        XCTAssertTrue(moved.isEmpty)
        XCTAssertNil(defaults.object(forKey: CategoryEmojiStore.key))
    }

    func testNothingMovesToAServerWithoutEmoji() async throws {
        let store = store()
        store.set("🍕", for: 1)
        store.set("📁", for: 2)
        var sendCount = 0
        let mover = CategoryEmojiMover(store: store) { _, _ in sendCount += 1 }

        let moved = await mover.run(categories: [try category(id: 1, emoji: nil), try category(id: 2, emoji: nil)])

        XCTAssertTrue(moved.isEmpty)
        XCTAssertEqual(sendCount, 0)
        XCTAssertEqual(store.entries, [1: "🍕", 2: "📁"], "nothing is dropped either")
    }

    func testEmojiSavedInSettingsMeanwhileIsNotOverwritten() async throws {
        let store = store()
        store.set("🍕", for: 1)
        store.set("🍝", for: 2)
        var sent: [Int: String] = [:]
        let mover = CategoryEmojiMover(store: store) { categoryId, emoji in
            sent[categoryId] = emoji
            // Settings saves category 2 while category 1 is being sent and
            // forgets the phone's copy of it.
            if categoryId == 1 { store.remove(2) }
        }

        let moved = await mover.run(categories: [try category(id: 1), try category(id: 2)])

        XCTAssertEqual(sent, [1: "🍕"], "category 2's older emoji is not sent")
        XCTAssertEqual(moved, [1: "🍕"])
    }

    func testASecondCallerGetsTheRunningMovesResult() async throws {
        let store = store()
        store.set("🍕", for: 1)
        var release: CheckedContinuation<Void, Never>?
        var sendCount = 0
        let mover = CategoryEmojiMover(store: store) { _, _ in
            sendCount += 1
            await withCheckedContinuation { release = $0 }
        }
        let categories = [try category(id: 1)]

        async let first = mover.run(categories: categories)
        while release == nil { await Task.yield() }
        async let second = mover.run(categories: categories)
        await Task.yield()
        release?.resume()

        let (firstMoved, secondMoved) = await (first, second)
        XCTAssertEqual(firstMoved, [1: "🍕"])
        XCTAssertEqual(secondMoved, [1: "🍕"], "the second caller shares the result")
        XCTAssertEqual(sendCount, 1, "the emoji is sent once")
    }

    func testArchivedCategoryMovesOnceRestored() async throws {
        let store = store()
        store.set("🍕", for: 1)
        var sent: [Int: String] = [:]
        let mover = CategoryEmojiMover(store: store) { categoryId, emoji in
            sent[categoryId] = emoji
        }

        await mover.run(categories: [try category(id: 1, archived: true)])
        XCTAssertTrue(sent.isEmpty)
        XCTAssertEqual(store.entries, [1: "🍕"])

        await mover.run(categories: [try category(id: 1, archived: false)])
        XCTAssertEqual(sent, [1: "🍕"])
        XCTAssertTrue(store.entries.isEmpty)
    }
}

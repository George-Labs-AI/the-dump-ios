import XCTest
@testable import The_Dump

/// Request bodies and responses for category management, checked against
/// what the web app sends and what the server returns.
final class CategoryRequestsTests: XCTestCase {
    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Re-sort request

    func testResortThenArchiveExcludesTheCategory() throws {
        let body = try jsonObject(StartRecategorizeRequest(scope: .category, categoryId: 42, archiving: true))
        XCTAssertEqual(body["scope"] as? String, "category")
        XCTAssertEqual(body["category_id"] as? Int, 42)
        XCTAssertEqual(body["archiving"] as? Bool, true)
        XCTAssertEqual(body["exclude_category_ids"] as? [Int], [42])
        XCTAssertEqual(body.count, 4)
    }

    func testPlainResortSendsNoExcludeKeys() throws {
        let body = try jsonObject(StartRecategorizeRequest(scope: .category, categoryId: 42))
        XCTAssertEqual(body["category_id"] as? Int, 42)
        XCTAssertNil(body["archiving"])
        XCTAssertNil(body["exclude_category_ids"])
        XCTAssertEqual(body.count, 2)
    }

    func testArchivingWithoutCategorySendsNoExcludeKeys() throws {
        let body = try jsonObject(StartRecategorizeRequest(scope: .all, categoryId: nil, archiving: true))
        XCTAssertEqual(body["scope"] as? String, "all")
        XCTAssertNil(body["category_id"])
        XCTAssertNil(body["exclude_category_ids"])
        XCTAssertNil(body["archiving"])
    }

    // MARK: - Name length (server rejects names over 80)

    func testNameIsCutBackToTheServerLimit() {
        XCTAssertEqual(CategoryLimits.maxNameLength, 80)
        let long = String(repeating: "a", count: 81)
        XCTAssertEqual(CategoryLimits.limitedName(long).count, 80)
        XCTAssertTrue(CategoryLimits.isNameAtLimit(CategoryLimits.limitedName(long)))

        let short = "Work"
        XCTAssertEqual(CategoryLimits.limitedName(short), short)
        XCTAssertFalse(CategoryLimits.isNameAtLimit(short))
    }

    func testNameLimitCountsCodePointsAndNeverSplitsAnEmoji() {
        // A family emoji is one character on screen but five code points,
        // which is how the server's Python len() counts it.
        let family = "👨‍👩‍👧"
        XCTAssertEqual(family.unicodeScalars.count, 5)
        let name = String(repeating: "a", count: 77) + family
        let limited = CategoryLimits.limitedName(name)
        XCTAssertEqual(limited, String(repeating: "a", count: 77))
        XCTAssertLessThanOrEqual(limited.unicodeScalars.count, 80)
    }

    func testSpacesAroundTheNameDontCount() {
        // The server trims surrounding spaces before counting.
        let eighty = String(repeating: "a", count: 80)
        XCTAssertEqual(CategoryLimits.nameLength("  \(eighty)  "), 80)
        XCTAssertEqual(CategoryLimits.limitedName("  \(eighty)  "), "  \(eighty)  ")
        XCTAssertEqual(CategoryLimits.limitedName("  \(eighty)b "), "  \(eighty)")
        XCTAssertTrue(CategoryLimits.isNameAtLimit(" \(eighty) "))
        XCTAssertFalse(CategoryLimits.isNameAtLimit(String(repeating: " ", count: 90)))
        // Spaces inside the name do count.
        let spaced = String(repeating: "a b ", count: 21)
        XCTAssertEqual(CategoryLimits.nameLength(CategoryLimits.limitedName(spaced)), 79)
    }

    // MARK: - Restore response (POST /api/categories/<id>/restore)

    func testRestoreResponseDecodesBothServerShapes() throws {
        let restored = try JSONDecoder().decode(RestoreCategoryResponse.self, from: Data("""
        {"status": "success", "category_id": 217, "restored_subcategory_count": 2}
        """.utf8))
        XCTAssertEqual(restored.categoryId, 217)
        XCTAssertEqual(restored.restoredSubcategoryCount, 2)
        XCTAssertNil(restored.alreadyActive)

        // Captured from the live server for a category that was already active.
        let noop = try JSONDecoder().decode(RestoreCategoryResponse.self, from: Data("""
        {"already_active": true, "category_id": 217, "restored_subcategory_count": 0, "status": "success"}
        """.utf8))
        XCTAssertEqual(noop.alreadyActive, true)
        XCTAssertEqual(noop.restoredSubcategoryCount, 0)
    }
}

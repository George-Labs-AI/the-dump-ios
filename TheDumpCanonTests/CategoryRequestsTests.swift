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

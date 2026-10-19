import XCTest
@testable import The_Dump

/// Request bodies and responses for category management, checked against
/// what the web app sends and what the server returns.
final class CategoryRequestsTests: XCTestCase {
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

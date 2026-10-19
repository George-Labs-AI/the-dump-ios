import XCTest
@testable import The_Dump

/// Sub-category filter pills come from the server's list of sub-categories,
/// so a new one with no notes yet still shows. Names in /api/category_map are
/// lower-cased; the filter must send the spelling stored on notes.
@MainActor
final class SubCategoryPillsTests: XCTestCase {
    private let map = CategoryMapResponse(
        categories: ["personal", "work"],
        subcategoriesByCategory: [
            "personal": ["finances", "health"],
            "work": ["meetings", "project ideas"],
        ]
    )

    func testDecodesCategoryMap() async throws {
        let decoded = try JSONDecoder().decode(CategoryMapResponse.self, from: Data("""
        {"categories": ["personal", "work"],
         "subcategories_by_category": {"personal": ["finances", "health"], "recipes": ["desserts"]}}
        """.utf8))
        XCTAssertEqual(decoded.categories, ["personal", "work"])
        XCTAssertEqual(decoded.subCategories(forCategory: "Recipes"), ["desserts"])

        let empty = try JSONDecoder().decode(CategoryMapResponse.self, from: Data("{}".utf8))
        XCTAssertEqual(empty, CategoryMapResponse(categories: [], subcategoriesByCategory: [:]))
    }

    func testEmptySubCategoriesShowWithZero() async {
        let pills = SubCategoryPills.build(
            categoryName: "Work", map: map, counts: ["meetings": 4], namesOnNotes: ["meetings"]
        )
        XCTAssertEqual(pills, [
            SubCategoryPill(name: "meetings", count: 4),
            SubCategoryPill(name: "project ideas", count: 0),
        ])
    }

    func testCategoryMatchedIgnoringCaseAndSpaces() async {
        let pills = SubCategoryPills.build(categoryName: "  PERSONAL ", map: map, counts: nil, namesOnNotes: [])
        XCTAssertEqual(pills.map(\.name), ["finances", "health"])
        XCTAssertEqual(pills.map(\.count), [nil, nil], "no counts loaded: no numbers shown")
    }

    // A note's stored spelling is what the server's filter matches exactly.
    func testStoredSpellingWins() async {
        let fromCounts = SubCategoryPills.build(
            categoryName: "work", map: map, counts: ["Project Ideas": 2], namesOnNotes: []
        )
        XCTAssertEqual(fromCounts.first { $0.id == "project ideas" }, SubCategoryPill(name: "Project Ideas", count: 2))

        let fromNotes = SubCategoryPills.build(
            categoryName: "work", map: map, counts: ["project ideas": 5, "Project Ideas": 1],
            namesOnNotes: ["Project Ideas"]
        )
        XCTAssertEqual(fromNotes.first { $0.id == "project ideas" }, SubCategoryPill(name: "Project Ideas", count: 1))
    }

    func testMoreCommonSpellingWinsWhenNotesDisagree() async {
        let pills = SubCategoryPills.build(
            categoryName: "work", map: map, counts: ["Meetings": 1, "meetings": 6], namesOnNotes: []
        )
        XCTAssertEqual(pills.first { $0.id == "meetings" }, SubCategoryPill(name: "meetings", count: 6))
    }

    // Archived categories are missing from the map; their notes still give pills.
    func testNamesOnNotesAreKeptWhenMapLacksThem() async {
        let pills = SubCategoryPills.build(
            categoryName: "Old Stuff", map: map, counts: ["Receipts": 3], namesOnNotes: ["Receipts", ""]
        )
        XCTAssertEqual(pills, [SubCategoryPill(name: "Receipts", count: 3)])
    }

    func testFallsBackToNotesWithoutMap() async {
        let pills = SubCategoryPills.build(
            categoryName: "work", map: nil, counts: nil, namesOnNotes: ["meetings", "Meetings", "budget"]
        )
        XCTAssertEqual(pills.map(\.id), ["budget", "meetings"])
    }

    // Counts are by name across all categories; names from other categories
    // never become pills here.
    func testCountsDontAddPills() async {
        let pills = SubCategoryPills.build(
            categoryName: "personal", map: map, counts: ["meetings": 9, "health": 1], namesOnNotes: []
        )
        XCTAssertEqual(pills.map(\.name), ["finances", "health"])
        XCTAssertEqual(pills.map(\.count), [0, 1])
    }

    func testJustCreatedSubCategoryShowsOnce() async {
        let pills = SubCategoryPills.build(
            categoryName: "work", map: map, counts: [:], namesOnNotes: [], added: ["Meetings", "Travel"]
        )
        XCTAssertEqual(pills.map(\.name), ["meetings", "project ideas", "Travel"])
    }
}

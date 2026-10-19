import XCTest
@testable import The_Dump

/// "Export my data" saves the server's JSON to a temporary file for the share
/// sheet, keeping at most one export on the phone.
final class DataExportTests: XCTestCase {
    private let temp = FileManager.default.temporaryDirectory

    private func localDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        guard let date = Calendar(identifier: .gregorian).date(from: components) else {
            XCTFail("Invalid test date \(year)-\(month)-\(day)")
            return .distantPast
        }
        return date
    }

    override func tearDown() {
        DataExport.removeEarlierExports()
        super.tearDown()
    }

    func testFileNameHasTheDateAndNoEmail() {
        XCTAssertEqual(DataExport.fileName(on: localDate(2026, 3, 7)), "the-dump-export-2026-03-07.json")
    }

    func testSavingWritesTheExportAndReplacesTheSameDaysFile() throws {
        let day = localDate(2001, 1, 2)
        let first = try DataExport.saveToTemporaryFile(Data(#"{"notes": []}"#.utf8), on: day)
        XCTAssertEqual(first.lastPathComponent, "the-dump-export-2001-01-02.json")
        XCTAssertEqual(first.deletingLastPathComponent().standardizedFileURL, temp.standardizedFileURL)

        let second = try DataExport.saveToTemporaryFile(Data(#"{"notes": [1]}"#.utf8), on: day)
        XCTAssertEqual(second, first)
        XCTAssertEqual(try Data(contentsOf: second), Data(#"{"notes": [1]}"#.utf8))
    }

    func testSavingANewExportRemovesEarlierOnes() throws {
        let older = try DataExport.saveToTemporaryFile(Data("{}".utf8), on: localDate(2001, 1, 3))
        let newer = try DataExport.saveToTemporaryFile(Data("{}".utf8), on: localDate(2001, 1, 4))
        XCTAssertFalse(FileManager.default.fileExists(atPath: older.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newer.path))
    }

    func testCleanupLeavesOtherTemporaryFilesAlone() throws {
        let other = temp.appendingPathComponent("not-an-export-\(UUID().uuidString).json")
        try Data("{}".utf8).write(to: other)
        defer { try? FileManager.default.removeItem(at: other) }
        let export = try DataExport.saveToTemporaryFile(Data("{}".utf8), on: localDate(2001, 1, 5))

        DataExport.removeEarlierExports()
        XCTAssertFalse(FileManager.default.fileExists(atPath: export.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: other.path))
    }
}

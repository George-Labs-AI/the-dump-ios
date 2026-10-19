import XCTest
@testable import The_Dump

/// "Export my data" saves the server's JSON to a temporary file for the share
/// sheet and deletes it afterwards.
final class DataExportTests: XCTestCase {
    private func localDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    func testFileNameHasTheDateAndNoEmail() {
        XCTAssertEqual(DataExport.fileName(on: localDate(2026, 3, 7)), "the-dump-export-2026-03-07.json")
    }

    func testSavingWritesTheExportAndReplacesTheSameDaysFile() throws {
        let day = localDate(2001, 1, 2)
        let first = try DataExport.saveToTemporaryFile(Data(#"{"notes": []}"#.utf8), on: day)
        defer { DataExport.removeTemporaryFile(at: first) }
        XCTAssertEqual(first.lastPathComponent, "the-dump-export-2001-01-02.json")
        XCTAssertEqual(first.deletingLastPathComponent().standardizedFileURL,
                       FileManager.default.temporaryDirectory.standardizedFileURL)

        let second = try DataExport.saveToTemporaryFile(Data(#"{"notes": [1]}"#.utf8), on: day)
        XCTAssertEqual(second, first)
        XCTAssertEqual(try Data(contentsOf: second), Data(#"{"notes": [1]}"#.utf8))
    }

    func testRemovingDeletesTheFileAndToleratesAMissingOne() throws {
        let url = try DataExport.saveToTemporaryFile(Data("{}".utf8), on: localDate(2001, 1, 3))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        DataExport.removeTemporaryFile(at: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        DataExport.removeTemporaryFile(at: url)
    }
}

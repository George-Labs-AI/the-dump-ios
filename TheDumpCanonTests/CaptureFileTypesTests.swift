import XCTest
@testable import The_Dump

/// The File button must accept exactly what the web uploader accepts
/// (validateFileTypes in the web app's static/index.js), and turn videos and
/// zips away with a message instead of uploading them.
final class CaptureFileTypesTests: XCTestCase {

    func testAllowedListMatchesTheWeb() {
        let web: [String] = [
            "txt", "jpg", "jpeg", "png", "pdf", "doc", "docx", "heic", "mp3", "wav", "m4a",
            "flac", "xlsx", "xls", "ppt", "pptx", "odt", "html", "csv", "svg", "odp", "key"
        ]
        XCTAssertEqual(CaptureFileTypes.allowedExtensions, Set(web))
        XCTAssertEqual(CaptureFileTypes.allowedExtensions.count, web.count)
    }

    func testAllowedFilesPassWhateverTheCase() {
        for name in ["notes.txt", "Scan.PDF", "IMG_0001.HEIC", "memo.m4a", "deck.Key", "a.b.docx"] {
            XCTAssertNil(CaptureFileTypes.rejection(forFilename: name), name)
        }
    }

    func testVideosAreNamedAsVideos() {
        for name in ["trip.mov", "clip.MP4", "screen.m4v", "old.avi"] {
            XCTAssertEqual(CaptureFileTypes.rejection(forFilename: name), .video, name)
        }
    }

    func testZipsAreNamedAsArchives() {
        for name in ["photos.zip", "Backup.ZIP", "logs.tar.gz", "stuff.7z"] {
            XCTAssertEqual(CaptureFileTypes.rejection(forFilename: name), .archive, name)
        }
    }

    func testEverythingElseIsTurnedAway() {
        // Off the web's list (including Pages and GIF), or no extension at
        // all — the web rejects those too.
        for name in ["setup.exe", "letter.pages", "funny.gif", "README", "archive."] {
            XCTAssertEqual(CaptureFileTypes.rejection(forFilename: name), .other, name)
        }
    }

    func testNoNoticeWhenEveryFileIsAllowed() {
        XCTAssertNil(CaptureFileTypes.skippedNotice(forFilenames: ["a.pdf", "b.jpg"]))
        XCTAssertNil(CaptureFileTypes.skippedNotice(forFilenames: []))
    }

    func testOneVideoNamesTheFileAndSaysWhy() throws {
        let notice = try XCTUnwrap(CaptureFileTypes.skippedNotice(forFilenames: ["a.pdf", "trip.mov"]))
        XCTAssertEqual(notice.title, "File not supported")
        XCTAssertEqual(notice.message, "“trip.mov” wasn't uploaded. Videos aren't supported yet.")
    }

    func testOneZipSaysToUnzipFirst() throws {
        let notice = try XCTUnwrap(CaptureFileTypes.skippedNotice(forFilenames: ["photos.zip"]))
        XCTAssertEqual(
            notice.message,
            "“photos.zip” wasn't uploaded. Zip files aren't supported yet, so unzip first and pick the files inside."
        )
    }

    func testSeveralRejectedFilesShareOneNotice() throws {
        let notice = try XCTUnwrap(CaptureFileTypes.skippedNotice(
            forFilenames: ["trip.mov", "ok.pdf", "photos.zip", "setup.exe"]
        ))
        XCTAssertEqual(notice.title, "Files not supported")
        XCTAssertTrue(notice.message.hasPrefix(
            "3 files weren't uploaded: “trip.mov”, “photos.zip”, “setup.exe”."
        ), notice.message)
        XCTAssertTrue(notice.message.contains("Videos aren't supported yet."))
        XCTAssertTrue(notice.message.contains("Zip files aren't supported yet"))
        XCTAssertTrue(notice.message.contains("The Dump can read photos, PDFs"))
        XCTAssertFalse(notice.message.contains("ok.pdf"))
    }
}

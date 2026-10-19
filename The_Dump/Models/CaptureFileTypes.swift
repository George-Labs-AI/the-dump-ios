import Foundation

// Which picked files the capture screen's File button uploads.
//
// The allowed list is the web uploader's (validateFileTypes in the web app's
// static/index.js), so both platforms accept exactly the same files. Anything
// else is turned away before upload with a message, instead of uploading and
// then showing up as a failed note. Foundation only, so it can be unit-tested
// without the app's services.

/// Why a picked file was turned away. Videos and zips get named outright
/// because they are what people most often try (the capture screen's hint
/// card already says neither is supported yet).
enum CaptureFileRejection: Equatable, Sendable {
    case video
    case archive
    case other
}

enum CaptureFileTypes {
    /// Same list, same order as the web's `allowedTypes`. Keep the two in step.
    static let allowedExtensions: Set<String> = [
        "txt", "jpg", "jpeg", "png", "pdf", "doc", "docx", "heic", "mp3", "wav", "m4a",
        "flac", "xlsx", "xls", "ppt", "pptx", "odt", "html", "csv", "svg", "odp", "key"
    ]

    /// Spelled out rather than asked of UTType, so the answer is the same on
    /// every iOS version and in tests.
    static let videoExtensions: Set<String> = [
        "mov", "mp4", "m4v", "avi", "mkv", "webm", "wmv", "flv", "3gp", "3g2",
        "mpg", "mpeg", "mts", "m2ts", "hevc"
    ]

    static let archiveExtensions: Set<String> = [
        "zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz"
    ]

    /// nil when the file can be uploaded. Like the web, only the extension
    /// counts (case-insensitive), and a name with no extension is turned away.
    static func rejection(forFilename filename: String) -> CaptureFileRejection? {
        let ext = (filename as NSString).pathExtension.lowercased()
        if allowedExtensions.contains(ext) { return nil }
        if videoExtensions.contains(ext) { return .video }
        if archiveExtensions.contains(ext) { return .archive }
        return .other
    }

    /// One alert for every file turned away from a single pick (nil when
    /// none were), so a batch shows one alert rather than one per file.
    static func skippedNotice(forFilenames filenames: [String]) -> (title: String, message: String)? {
        let rejected = filenames.compactMap { name in
            rejection(forFilename: name).map { (name: name, reason: $0) }
        }
        guard !rejected.isEmpty else { return nil }

        let quoted = rejected.map { "“\($0.name)”" }
        var sentences = [
            rejected.count == 1
                ? "\(quoted[0]) wasn't uploaded."
                : "\(rejected.count) files weren't uploaded: \(quoted.joined(separator: ", "))."
        ]
        let reasons = Set(rejected.map(\.reason))
        if reasons.contains(.video) {
            sentences.append("Videos aren't supported yet.")
        }
        if reasons.contains(.archive) {
            sentences.append("Zip files aren't supported yet, so unzip first and pick the files inside.")
        }
        if reasons.contains(.other) {
            sentences.append("The Dump can read photos, PDFs, text, Word, Excel, PowerPoint and Keynote files, and audio.")
        }
        let title = rejected.count == 1 ? "File not supported" : "Files not supported"
        return (title, sentences.joined(separator: " "))
    }
}

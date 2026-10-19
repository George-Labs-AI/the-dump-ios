import Foundation

/// Saves the account export from GET /export-data as a JSON file the share
/// sheet can hand to Files, Mail, AirDrop and so on.
enum DataExport {
    private static let filePrefix = "the-dump-export-"

    /// e.g. "the-dump-export-2026-10-18.json". Deliberately leaves the email
    /// out, because the file name shows wherever the file is shared.
    static func fileName(on date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(filePrefix)\(formatter.string(from: date)).json"
    }

    /// Writes `data` to the app's temporary folder and returns the file's
    /// location. Earlier exports are removed first, so at most one copy is
    /// kept, inside the app's own storage, until the next export or until
    /// iOS clears temporary files. The file isn't deleted when the share
    /// sheet closes, because Files, Mail and other destinations can still be
    /// reading it then. It keeps the default file protection rather than
    /// "complete" for the same reason: a share can outlast a screen lock, and
    /// a completely protected file becomes unreadable once the phone locks.
    static func saveToTemporaryFile(_ data: Data, on date: Date = Date()) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
        removeEarlierExports(in: directory)
        let url = directory.appendingPathComponent(fileName(on: date))
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Deletes every export file left in `directory` by an earlier export.
    static func removeEarlierExports(in directory: URL = FileManager.default.temporaryDirectory) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in names where name.hasPrefix(filePrefix) && name.hasSuffix(".json") {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }
}

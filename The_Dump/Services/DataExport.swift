import Foundation

/// Saves the account export from GET /export-data as a JSON file the share
/// sheet can hand to Files, Mail, AirDrop and so on.
enum DataExport {
    /// e.g. "the-dump-export-2026-10-18.json". Deliberately leaves the email
    /// out, because the file name shows wherever the file is shared.
    static func fileName(on date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return "the-dump-export-\(formatter.string(from: date)).json"
    }

    /// Writes `data` to the app's temporary folder, replacing an earlier
    /// export from the same day, and returns the file's location.
    static func saveToTemporaryFile(_ data: Data, on date: Date = Date()) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(on: date))
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    /// Removes a shared export once the share sheet closes, so a copy of
    /// every note doesn't linger on the phone.
    static func removeTemporaryFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

import Foundation

// Note dates arrive in more than one form: /api/pull_notes sends ISO-8601
// with microseconds ("2026-10-19T03:14:35.634209Z"), /api/pull_full_notes
// sends an HTTP date ("Fri, 16 Oct 2026 02:40:13 GMT"), and the edit
// response's ISO string may have no time zone. A plain ISO8601DateFormatter
// reads only "2026-10-19T03:14:35Z", so dates silently went missing.
enum NoteDates {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let httpDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "GMT")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f
    }()

    // A server timestamp with no zone is UTC.
    private static let noZone: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()

    static func parse(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if let date = withFraction.date(from: raw) ?? plain.date(from: raw) ?? httpDate.date(from: raw) {
            return date
        }
        // "2026-10-19T03:14:35.634209": drop the fraction, read the rest as UTC.
        let wholeSeconds = raw.split(separator: ".", maxSplits: 1).first.map(String.init) ?? raw
        return noZone.date(from: wholeSeconds)
    }
}

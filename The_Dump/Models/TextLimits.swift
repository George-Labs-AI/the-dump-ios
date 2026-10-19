import Foundation

/// Length limits counted the way the server counts them: in Unicode code
/// points, which is what Python's `len()` returns. A character is never
/// split, so an emoji at a limit is dropped whole.
enum TextLimits {
    /// The length the server checks for a name: code points after trimming
    /// spaces around it.
    static func nameLength(_ text: String) -> Int {
        text.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count
    }

    /// `text` cut back so that `nameLength` is at most `limit`. Spaces
    /// around the name don't count toward it.
    static func limitedName(_ text: String, to limit: Int) -> String {
        guard nameLength(text) > limit else { return text }
        let leading = text.prefix { $0.isWhitespace }
        return String(leading) + limited(String(text.dropFirst(leading.count)), to: limit)
    }

    /// `text` cut back to `limit` code points, spaces included.
    static func limited(_ text: String, to limit: Int) -> String {
        var kept = ""
        var count = 0
        for character in text {
            count += character.unicodeScalars.count
            if count > limit { break }
            kept.append(character)
        }
        return kept
    }
}

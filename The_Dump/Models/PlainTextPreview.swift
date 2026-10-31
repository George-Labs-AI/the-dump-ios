import Foundation

/// Note previews arrive as raw markdown: the first few hundred characters of
/// the body, or of the text read from a photo or recording. Rows show them as
/// clean text, so the markup is stripped and the lines are joined.
nonisolated enum PlainTextPreview {
    static func text(from markdown: String) -> String {
        let lines = markdown
            .components(separatedBy: .newlines)
            .map(stripLineMarkers)
            .filter { !$0.isEmpty }
        var text = lines.joined(separator: " ")
        for (pattern, template) in inlineRules {
            text = text.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        return text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Block markers at the start of a line: quotes, the label a photo's or
    /// document's description starts with ("*Image (photo):*", on its own
    /// line, after any text read from it), headings, rules, list bullets,
    /// numbers and task boxes. Rules come before bullets, so "* * *" isn't
    /// read as a bullet.
    private static func stripLineMarkers(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespaces)
        let prefixes = [
            #"^(>\s*)+"#,
            #"^\*?(Image|Audio|Document|File) \([^)]*\):\*?\s*"#,
            #"^#{1,6}\s+"#,
            #"^([-*_]\s*){3,}$"#,
            #"^([-*+]|\d+[.)])\s+"#,
            #"^\[[ xX]\]\s+"#
        ]
        for pattern in prefixes {
            text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return text
    }

    /// Inline markup, in order: images and links keep their words; bold,
    /// italic, strikethrough and code keep their text.
    private static let inlineRules: [(String, String)] = [
        (#"!\[([^\]]*)\]\([^)]*\)"#, "$1"),
        (#"\[([^\]]+)\]\([^)]*\)"#, "$1"),
        (#"(\*\*|__)(.+?)\1"#, "$2"),
        (#"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])"#, "$1"),
        (#"(?<![\w_])_(?!\s)(.+?)(?<!\s)_(?![\w_])"#, "$1"),
        (#"~~(.+?)~~"#, "$1"),
        (#"`([^`]*)`"#, "$1")
    ]
}

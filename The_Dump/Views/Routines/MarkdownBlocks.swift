import SwiftUI

// Lightweight block-level markdown for routine documents.
//
// Runner-authored documents are untrusted markdown that can run to hundreds
// of KB. SwiftUI's AttributedString(markdown:) is inline-only in practice
// (it collapses block structure and chokes on large inputs), so the body is
// split into blocks here — headings, paragraphs, list items, fenced code,
// tables, quotes, rules — and each block is rendered as its own Text in a
// LazyVStack. Inline markdown (bold, italic, code, links) is parsed per block.
//
// Link safety: only http(s) links and the runner's `[[note:<uuid>]]`
// provenance token (rewritten to thedump://note/<uuid>) survive. The
// document view's openURL handler is the second gate.

nonisolated enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case listItem(indent: Int, ordered: Bool, marker: String, text: String)
    case code(String)
    case table([String])
    case quote(String)
    case rule
}

nonisolated struct IndexedMarkdownBlock: Identifiable, Equatable, Sendable {
    let id: Int
    let block: MarkdownBlock
}

nonisolated enum MarkdownBlockParser {
    static let noteLinkScheme = "thedump"
    static let noteLinkHost = "note"

    /// Split a whole document into renderable blocks. Pure and thread-safe;
    /// call it off the main actor for large bodies.
    static func parse(_ body: String) -> [IndexedMarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var codeLines: [String] = []
        var inCode = false
        var tableLines: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph.removeAll()
            }
        }
        func flushTable() {
            if !tableLines.isEmpty {
                blocks.append(.table(tableLines))
                tableLines.removeAll()
            }
        }

        let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
        for rawLine in lines {
            var line = String(rawLine)
            if line.hasSuffix("\r") { line.removeLast() }
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if inCode {
                if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                    blocks.append(.code(codeLines.joined(separator: "\n")))
                    codeLines.removeAll()
                    inCode = false
                } else {
                    codeLines.append(line)
                }
                continue
            }

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                flushParagraph(); flushTable()
                inCode = true
                continue
            }

            if trimmed.hasPrefix("|") {
                flushParagraph()
                tableLines.append(trimmed)
                continue
            } else {
                flushTable()
            }

            if trimmed.isEmpty {
                flushParagraph()
                continue
            }

            if let heading = parseHeading(trimmed) {
                flushParagraph()
                blocks.append(heading)
                continue
            }

            if isRule(trimmed) {
                flushParagraph()
                blocks.append(.rule)
                continue
            }

            if trimmed.hasPrefix(">") {
                flushParagraph()
                let text = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                if case .quote(let existing)? = blocks.last {
                    blocks[blocks.count - 1] = .quote(existing + " " + text)
                } else {
                    blocks.append(.quote(text))
                }
                continue
            }

            if let item = parseListItem(line) {
                flushParagraph()
                blocks.append(item)
                continue
            }

            paragraph.append(trimmed)
        }

        if inCode {
            blocks.append(.code(codeLines.joined(separator: "\n")))
        }
        flushParagraph()
        flushTable()

        return blocks.enumerated().map { IndexedMarkdownBlock(id: $0.offset, block: $0.element) }
    }

    private static func parseHeading(_ line: String) -> MarkdownBlock? {
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        var idx = line.startIndex
        while idx < line.endIndex, line[idx] == "#", level < 6 {
            level += 1
            idx = line.index(after: idx)
        }
        guard idx < line.endIndex, line[idx] == " " else { return nil }
        var text = line[idx...].trimmingCharacters(in: .whitespaces)
        // Strip optional closing hashes ("## Title ##").
        while text.hasSuffix("#") { text.removeLast() }
        return .heading(level: level, text: text.trimmingCharacters(in: .whitespaces))
    }

    private static func isRule(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3 else { return false }
        return compact.allSatisfy { $0 == "-" } || compact.allSatisfy { $0 == "*" } || compact.allSatisfy { $0 == "_" }
    }

    private static func parseListItem(_ line: String) -> MarkdownBlock? {
        let leading = line.prefix { $0 == " " || $0 == "\t" }
        let indent = leading.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) } / 2
        let rest = line.dropFirst(leading.count)

        if let first = rest.first, first == "-" || first == "*" || first == "+" {
            let after = rest.dropFirst()
            guard after.first == " " else { return nil }
            var text = after.trimmingCharacters(in: .whitespaces)
            var marker = "•"
            // Task-list checkboxes.
            if text.hasPrefix("[ ] ") {
                marker = "☐"
                text = String(text.dropFirst(4))
            } else if text.lowercased().hasPrefix("[x] ") {
                marker = "☑"
                text = String(text.dropFirst(4))
            }
            return .listItem(indent: indent, ordered: false, marker: marker, text: text)
        }

        // Ordered: "1. text" or "1) text"
        let digits = rest.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 4 else { return nil }
        let afterDigits = rest.dropFirst(digits.count)
        guard let punct = afterDigits.first, punct == "." || punct == ")" else { return nil }
        let afterPunct = afterDigits.dropFirst()
        guard afterPunct.first == " " else { return nil }
        return .listItem(
            indent: indent,
            ordered: true,
            marker: "\(digits).",
            text: afterPunct.trimmingCharacters(in: .whitespaces)
        )
    }

    // MARK: - Inline

    // Patterns are literals, so a compile failure is a programming error;
    // fall back to a never-matching regex rather than crashing the viewer.
    private static func regex(_ pattern: String) -> NSRegularExpression {
        if let compiled = try? NSRegularExpression(pattern: pattern) {
            return compiled
        }
        assertionFailure("invalid markdown regex: \(pattern)")
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(pattern: #"(?!)"#)
    }

    private static let noteTokenRegex = regex(#"\[\[note:([0-9a-fA-F-]{36})\]\]"#)
    private static let linkRegex = regex(#"\[([^\]]*)\]\(([^\s]*)(?:\s+"[^"]*")?\)"#)
    private static let autolinkRegex = regex(#"<([a-zA-Z][a-zA-Z0-9+.-]*:[^>\s]*)>"#)

    /// Rewrite provenance tokens to in-app links and drop any link whose
    /// scheme is not http(s). Returns markdown ready for inline parsing.
    static func sanitizeInline(_ text: String) -> String {
        var out = text
        let full = NSRange(out.startIndex..., in: out)

        out = noteTokenRegex.stringByReplacingMatches(
            in: out, range: full,
            withTemplate: "[note](\(noteLinkScheme)://\(noteLinkHost)/$1)"
        )

        // Markdown links: keep only http(s) and our note scheme.
        var result = ""
        var lastEnd = out.startIndex
        for match in linkRegex.matches(in: out, range: NSRange(out.startIndex..., in: out)) {
            guard let whole = Range(match.range, in: out),
                  let labelRange = Range(match.range(at: 1), in: out),
                  let urlRange = Range(match.range(at: 2), in: out) else { continue }
            result += out[lastEnd..<whole.lowerBound]
            let url = String(out[urlRange])
            if isAllowedURL(url) {
                result += out[whole]
            } else {
                result += out[labelRange]
            }
            lastEnd = whole.upperBound
        }
        result += out[lastEnd...]

        // Autolinks like <javascript:...> — drop anything not http(s).
        var final = ""
        lastEnd = result.startIndex
        for match in autolinkRegex.matches(in: result, range: NSRange(result.startIndex..., in: result)) {
            guard let whole = Range(match.range, in: result),
                  let urlRange = Range(match.range(at: 1), in: result) else { continue }
            final += result[lastEnd..<whole.lowerBound]
            let url = String(result[urlRange])
            final += isAllowedURL(url) ? String(result[whole]) : url
            lastEnd = whole.upperBound
        }
        final += result[lastEnd...]
        return final
    }

    static func isAllowedURL(_ raw: String) -> Bool {
        let lower = raw.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") { return true }
        return lower.hasPrefix("\(noteLinkScheme)://\(noteLinkHost)/")
    }

    /// Inline markdown → AttributedString, falling back to plain text.
    static func attributed(_ text: String) -> AttributedString {
        let safe = sanitizeInline(text)
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        options.failurePolicy = .returnPartiallyParsedIfPossible
        if let parsed = try? AttributedString(markdown: safe, options: options) {
            return parsed
        }
        return AttributedString(safe)
    }

    /// Note id from a thedump://note/<uuid> link, if that's what this is.
    static func noteID(from url: URL) -> String? {
        guard url.scheme?.lowercased() == noteLinkScheme,
              url.host?.lowercased() == noteLinkHost else { return nil }
        let id = url.lastPathComponent
        return id.isEmpty ? nil : id
    }
}

// MARK: - Block view

struct MarkdownBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        switch block {
        case .heading(let level, let text):
            Text(MarkdownBlockParser.attributed(text))
                .font(headingFont(level))
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, level <= 2 ? Theme.spacingSM : Theme.spacingXS)
                .textSelection(.enabled)

        case .paragraph(let text):
            Text(MarkdownBlockParser.attributed(text))
                .font(.system(size: Theme.fontSizeMD))
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

        case .listItem(let indent, _, let marker, let text):
            HStack(alignment: .firstTextBaseline, spacing: Theme.spacingSM) {
                Text(marker)
                    .font(.system(size: Theme.fontSizeMD))
                    .foregroundColor(Theme.textSecondary)
                    .frame(minWidth: 18, alignment: .trailing)
                Text(MarkdownBlockParser.attributed(text))
                    .font(.system(size: Theme.fontSizeMD))
                    .foregroundColor(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(.leading, CGFloat(min(indent, 6)) * Theme.spacingMD)

        case .code(let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: Theme.fontSizeSM, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                    .textSelection(.enabled)
                    .padding(Theme.spacingSMPlus)
            }
            .background(Theme.surface2)
            .cornerRadius(Theme.cornerRadiusSM)

        case .table(let rows):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(rows.joined(separator: "\n"))
                    .font(.system(size: Theme.fontSizeXS, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                    .textSelection(.enabled)
                    .padding(Theme.spacingSMPlus)
            }
            .background(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSM)
                    .stroke(Theme.borderLight, lineWidth: 1)
            )
            .cornerRadius(Theme.cornerRadiusSM)

        case .quote(let text):
            HStack(alignment: .top, spacing: Theme.spacingSMPlus) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.border)
                    .frame(width: 3)
                Text(MarkdownBlockParser.attributed(text))
                    .font(.system(size: Theme.fontSizeMD))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }

        case .rule:
            Rectangle()
                .fill(Theme.borderLight)
                .frame(height: 1)
                .padding(.vertical, Theme.spacingXS)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .system(size: Theme.fontSizeXL, weight: .bold)
        case 2: return .system(size: 20, weight: .bold)
        case 3: return .system(size: Theme.fontSizeLG, weight: .semibold)
        default: return .system(size: Theme.fontSizeMD, weight: .semibold)
        }
    }
}

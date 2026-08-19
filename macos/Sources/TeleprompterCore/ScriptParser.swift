import Foundation

public enum ScriptParser {
    private static let actionWords: Set<String> = [
        "draw", "write", "tap", "circle", "erase", "point", "underline", "label"
    ]

    public static func parse(_ markdown: String) -> [Block] {
        if hasLabeledMarkers(markdown) {
            return parseLabeled(markdown)
        }
        if hasActionBrackets(markdown) {
            return parseBrackets(markdown)
        }
        return parsePlain(markdown)
    }

    private static func hasLabeledMarkers(_ text: String) -> Bool {
        text.range(of: #"\*\*SAY:\*\*"#, options: .regularExpression) != nil
            || text.range(of: #"\*\*DRAW"#, options: .regularExpression) != nil
    }

    private static func hasActionBrackets(_ text: String) -> Bool {
        paragraphs(in: text).contains { isActionBracket($0) }
    }

    private static func parsePlain(_ markdown: String) -> [Block] {
        var lines = markdown.components(separatedBy: "\n")
        if let first = lines.first, first.hasPrefix("# ") {
            lines.removeFirst()
        }
        lines.removeAll { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.range(of: #"^#{1,6}\s+"#, options: .regularExpression) != nil
                || trimmed.range(of: #"^---+$"#, options: .regularExpression) != nil
        }
        return sayParagraphs(from: lines.joined(separator: "\n"))
    }

    private static func parseLabeled(_ markdown: String) -> [Block] {
        let lines = markdown.components(separatedBy: "\n")
        guard let firstHeading = lines.firstIndex(where: { isHeading($0) }) else {
            return []
        }

        var blocks: [Block] = []
        var i = firstHeading
        var mode: String? = nil // "say" | "draw" | "skip"
        var buffer: [String] = []

        func flush() {
            let raw = buffer.joined(separator: "\n")
            buffer = []
            let current = mode
            mode = nil
            guard let current else { return }
            if current == "skip" { return }
            if current == "draw" {
                let stripped = MarkdownStripper.strip(raw)
                if !stripped.isEmpty { blocks.append(.draw(text: stripped)) }
                return
            }
            blocks.append(contentsOf: sayParagraphs(from: raw))
        }

        while i < lines.count {
            let line = lines[i]
            if isHorizontalRule(line) {
                i += 1
                continue
            }
            if isHeading(line) {
                flush()
                let title = headingTitle(line)
                if title.localizedCaseInsensitiveContains("production notes") {
                    mode = "skip"
                    buffer = []
                } else {
                    blocks.append(.segment(title: title))
                    mode = nil
                }
                i += 1
                continue
            }
            if isDrawMarker(line) {
                flush()
                mode = "draw"
                buffer = [line.replacingOccurrences(of: "**", with: "")]
                i += 1
                continue
            }
            if isSayMarker(line) {
                flush()
                mode = "say"
                buffer = []
                i += 1
                continue
            }
            if mode != nil {
                buffer.append(line)
            }
            i += 1
        }
        flush()
        return droppingEmptySegments(blocks)
    }

    private static func isHeading(_ line: String) -> Bool {
        line.range(of: #"^##\s+"#, options: .regularExpression) != nil
    }

    private static func headingTitle(_ line: String) -> String {
        MarkdownStripper.strip(line)
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).range(of: #"^---+$"#, options: .regularExpression) != nil
    }

    private static func isDrawMarker(_ line: String) -> Bool {
        line.range(of: #"^\s*\*\*(DRAW|ERASE|THEN DRAW)"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func droppingEmptySegments(_ blocks: [Block]) -> [Block] {
        blocks.enumerated().compactMap { index, block in
            guard case .segment = block else { return block }
            let untilNextSegment = blocks.suffix(from: index + 1).prefix {
                if case .segment = $0 { return false }
                return true
            }
            let hasContent = untilNextSegment.contains { content in
                switch content {
                case .say, .draw: return true
                case .segment: return false
                }
            }
            return hasContent ? block : nil
        }
    }

    private static func isSayMarker(_ line: String) -> Bool {
        line.range(of: #"^\s*\*\*SAY:\*\*"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func parseBrackets(_ markdown: String) -> [Block] {
        // Implemented in Task 5.
        []
    }

    static func sayParagraphs(from text: String) -> [Block] {
        let stripped = MarkdownStripper.strip(text)
        return stripped
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { Block.say(text: $0) }
    }

    static func paragraphs(in text: String) -> [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func isActionBracket(_ paragraph: String) -> Bool {
        guard let inner = bracketInner(paragraph) else { return false }
        let first = inner.split(whereSeparator: { $0 == " " || $0 == "." || $0 == ":" || $0 == "," }).first.map(String.init)?.lowercased()
        return first.map { actionWords.contains($0) } ?? false
    }

    static func isNonActionBracket(_ paragraph: String) -> Bool {
        bracketInner(paragraph) != nil && !isActionBracket(paragraph)
    }

    static func bracketInner(_ paragraph: String) -> String? {
        let t = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix("["), t.hasSuffix("]"), t.filter({ $0 == "[" }).count == 1 else { return nil }
        return String(t.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

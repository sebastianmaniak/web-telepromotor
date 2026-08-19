import Foundation

public enum MarkdownStripper {
    public static func strip(_ text: String) -> String {
        var s = text
        s = replace(s, pattern: "^#{1,6}\\s+", template: "")
        s = replace(s, pattern: "```[\\s\\S]*?```", template: "")
        s = replace(s, pattern: "`([^`]+)`", template: "$1")
        s = replace(s, pattern: "!\\[([^\\]]*)\\]\\([^)]+\\)", template: "")
        s = replace(s, pattern: "\\[([^\\]]+)\\]\\([^)]+\\)", template: "$1")
        s = replace(s, pattern: "(\\*\\*|__)(.*?)\\1", template: "$2")
        s = replace(s, pattern: "(\\*|_)(.*?)\\1", template: "$2")
        s = replace(s, pattern: "~~(.*?)~~", template: "$1")
        s = replace(s, pattern: "^>\\s+", template: "")
        s = replace(s, pattern: "^[-*+]\\s+", template: "")
        s = replace(s, pattern: "^\\d+\\.\\s+", template: "")
        s = replace(s, pattern: "^---+$", template: "")
        s = replace(s, pattern: "\\n{3,}", template: "\n\n")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replace(_ input: String, pattern: String, template: String) -> String {
        let regex = try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: template)
    }
}

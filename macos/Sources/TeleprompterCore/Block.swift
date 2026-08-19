import Foundation

public enum Block: Equatable, Sendable {
    case segment(_ title: String)
    case say(_ text: String)
    case draw(_ text: String)

    public static func spokenWordCount(_ blocks: [Block]) -> Int {
        blocks.reduce(0) { count, block in
            guard case .say(let text) = block else { return count }
            let words = text.split { $0.isWhitespace || $0.isNewline }
            return count + words.count
        }
    }

    public static func hasContent(_ blocks: [Block]) -> Bool {
        blocks.contains { block in
            switch block {
            case .say(let text), .draw(let text):
                return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .segment:
                return false
            }
        }
    }

    public static func displayName(filename: String) -> String {
        var base = filename
        if base.lowercased().hasSuffix(".md") {
            base = String(base.dropLast(3))
        }
        base = base.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        return base.split(separator: " ").map { word in
            let lower = word.lowercased()
            return lower.prefix(1).uppercased() + lower.dropFirst()
        }.joined(separator: " ")
    }
}

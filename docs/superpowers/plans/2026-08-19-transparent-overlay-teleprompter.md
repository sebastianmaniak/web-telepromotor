# Transparent Overlay Teleprompter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a native macOS menu-bar overlay that reads `scripts/*.md` (or any `.md` file), scrolls SAY text and DRAW cues on a full-screen transparent always-on-top window, and click-throughs to the app behind while playing.

**Architecture:** Swift Package under `macos/`. `TeleprompterCore` is a testable library (parser, engine, store) with no AppKit. `TeleprompterOverlay` is a SwiftUI + AppKit executable: menu-bar extra, transparent `NSWindow`, HUD, hotkeys, display-link. The existing GitHub Pages app is not modified.

**Tech Stack:** Swift 5.9+, macOS 14, SwiftUI, AppKit, Swift Package Manager, `swift test` / `swift run`. No third-party packages.

**Spec:** `docs/superpowers/specs/2026-08-19-transparent-overlay-teleprompter-design.md`

---

## File Map

| File | Responsibility |
|---|---|
| `macos/Package.swift` | Package: `TeleprompterCore` library, `TeleprompterOverlay` executable, `TeleprompterCoreTests` |
| `macos/Sources/TeleprompterCore/Block.swift` | `Block` enum, spoken word count, display name |
| `macos/Sources/TeleprompterCore/MarkdownStripper.swift` | Strip markdown markers to plain text |
| `macos/Sources/TeleprompterCore/ScriptParser.swift` | `.md` string → `[Block]` (formats A/B/C) |
| `macos/Sources/TeleprompterCore/TeleprompterEngine.swift` | Play/pause/restart, WPM→px/s, scroll clamp, timer |
| `macos/Sources/TeleprompterCore/ScriptStore.swift` | Resolve `scripts/`, list `.md`, last-path helpers |
| `macos/Sources/TeleprompterOverlay/App.swift` | `@main` App, accessory policy, `AppModel` environment |
| `macos/Sources/TeleprompterOverlay/AppModel.swift` | Load script, overlay show/hide, HUD auto-hide, settings |
| `macos/Sources/TeleprompterOverlay/OverlayWindowController.swift` | Transparent always-on-top NSWindow, click-through, screen pin |
| `macos/Sources/TeleprompterOverlay/OverlayView.swift` | SAY/DRAW/segment render, fades, guide line, drag-to-scroll |
| `macos/Sources/TeleprompterOverlay/ControlHUD.swift` | Bottom control bar |
| `macos/Sources/TeleprompterOverlay/MenuBarView.swift` | Menu extra: script list, open, timer, quit |
| `macos/Sources/TeleprompterOverlay/HotkeyCenter.swift` | Local/global keys + global mouse-move |
| `macos/Sources/TeleprompterOverlay/DisplayLinkDriver.swift` | CADisplayLink → `engine.tick(elapsed:)` |
| `macos/Tests/TeleprompterCoreTests/FixtureLoader.swift` | Load repo `scripts/*.md` from `#filePath` |
| `macos/Tests/TeleprompterCoreTests/MarkdownStripperTests.swift` | Strip cases |
| `macos/Tests/TeleprompterCoreTests/ScriptParserTests.swift` | Formats A/B/C + empty/heading-only |
| `macos/Tests/TeleprompterCoreTests/TeleprompterEngineTests.swift` | Play/pause/restart/WPM/clamp/timer |
| `macos/Tests/TeleprompterCoreTests/ScriptStoreTests.swift` | Folder resolve + listing |
| `macos/README.md` | How to test and run |

Do not modify `index.html`, `js/`, `css/`, `remote.html`, or `scripts/`.

---

### Task 1: Swift package scaffold

**Files:**
- Create: `macos/Package.swift`

- [ ] **Step 1: Create the package manifest**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TeleprompterOverlay",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TeleprompterCore", targets: ["TeleprompterCore"]),
        .executable(name: "TeleprompterOverlay", targets: ["TeleprompterOverlay"])
    ],
    targets: [
        .target(name: "TeleprompterCore"),
        .executableTarget(
            name: "TeleprompterOverlay",
            dependencies: ["TeleprompterCore"]
        ),
        .testTarget(
            name: "TeleprompterCoreTests",
            dependencies: ["TeleprompterCore"]
        )
    ]
)
```

- [ ] **Step 2: Verify the package parses**

Run: `cd macos && swift package dump-package`

Expected: JSON with targets `TeleprompterCore`, `TeleprompterOverlay`, `TeleprompterCoreTests`. No error.

- [ ] **Step 3: Commit**

```bash
git add macos/Package.swift
git commit -m "chore: scaffold macOS Swift package for overlay teleprompter"
```

---

### Task 2: Block types and markdown stripper (TDD)

**Files:**
- Create: `macos/Sources/TeleprompterCore/Block.swift`
- Create: `macos/Sources/TeleprompterCore/MarkdownStripper.swift`
- Create: `macos/Tests/TeleprompterCoreTests/MarkdownStripperTests.swift`
- Create: `macos/Tests/TeleprompterCoreTests/BlockTests.swift`

- [ ] **Step 1: Write the failing stripper and display-name tests**

`macos/Tests/TeleprompterCoreTests/MarkdownStripperTests.swift`:

```swift
import XCTest
@testable import TeleprompterCore

final class MarkdownStripperTests: XCTestCase {
    func testStripsBoldItalicLinksAndLists() {
        let input = """
        When Substrate **suspends** it, _resume_ into a [worker](https://example.com).
        - Top row: circles
        `atelet` stays
        """
        let out = MarkdownStripper.strip(input)
        XCTAssertFalse(out.contains("**"))
        XCTAssertFalse(out.contains("["))
        XCTAssertFalse(out.contains("`"))
        XCTAssertTrue(out.contains("suspends"))
        XCTAssertTrue(out.contains("worker"))
        XCTAssertTrue(out.contains("Top row: circles"))
        XCTAssertTrue(out.contains("atelet"))
    }

    func testCollapsesExtraBlankLines() {
        let out = MarkdownStripper.strip("a\n\n\n\nb")
        XCTAssertEqual(out, "a\n\nb")
    }
}
```

`macos/Tests/TeleprompterCoreTests/BlockTests.swift`:

```swift
import XCTest
@testable import TeleprompterCore

final class BlockTests: XCTestCase {
    func testSpokenWordCountIgnoresDrawAndSegment() {
        let blocks: [Block] = [
            .segment("SEGMENT 1"),
            .draw("DRAW (left): a box"),
            .say("Hello there friend"),
            .say("One two")
        ]
        XCTAssertEqual(Block.spokenWordCount(blocks), 5)
    }

    func testDisplayNameTitleCasesFilename() {
        XCTAssertEqual(Block.displayName(filename: "agent-registry.md"), "Agent Registry")
        XCTAssertEqual(Block.displayName(filename: "virtual_mcp.md"), "Virtual Mcp")
    }

    func testHasSpokenOrDrawContent() {
        XCTAssertFalse(Block.hasContent([.segment("Only")]))
        XCTAssertTrue(Block.hasContent([.say("Hi")]))
        XCTAssertTrue(Block.hasContent([.draw("Draw a box")]))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd macos && swift test --filter MarkdownStripperTests --filter BlockTests`

Expected: FAIL — `TeleprompterCore` types not found.

- [ ] **Step 3: Implement Block and MarkdownStripper**

`macos/Sources/TeleprompterCore/Block.swift`:

```swift
import Foundation

public enum Block: Equatable, Sendable {
    case segment(title: String)
    case say(text: String)
    case draw(text: String)

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
```

`macos/Sources/TeleprompterCore/MarkdownStripper.swift`:

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd macos && swift test --filter MarkdownStripperTests --filter BlockTests`

Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
git add macos/Sources/TeleprompterCore/Block.swift macos/Sources/TeleprompterCore/MarkdownStripper.swift macos/Tests/TeleprompterCoreTests/MarkdownStripperTests.swift macos/Tests/TeleprompterCoreTests/BlockTests.swift
git commit -m "feat: add Block types and markdown stripper"
```

---

### Task 3: ScriptParser — Format C and empty files (TDD)

**Files:**
- Create: `macos/Sources/TeleprompterCore/ScriptParser.swift`
- Create: `macos/Tests/TeleprompterCoreTests/FixtureLoader.swift`
- Create: `macos/Tests/TeleprompterCoreTests/ScriptParserTests.swift`

- [ ] **Step 1: Write failing tests for Format C, empty, heading-only**

`macos/Tests/TeleprompterCoreTests/FixtureLoader.swift`:

```swift
import Foundation

enum FixtureLoader {
    static func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            let scripts = dir.appendingPathComponent("scripts")
            let git = dir.appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: scripts.path),
               FileManager.default.fileExists(atPath: git.path) {
                return dir
            }
            dir.deleteLastPathComponent()
        }
        fatalError("Could not find repo root from \(#filePath)")
    }

    static func script(_ name: String) -> String {
        let url = repoRoot().appendingPathComponent("scripts").appendingPathComponent(name)
        return try! String(contentsOf: url, encoding: .utf8)
    }
}
```

`macos/Tests/TeleprompterCoreTests/ScriptParserTests.swift`:

```swift
import XCTest
@testable import TeleprompterCore

final class ScriptParserTests: XCTestCase {
    func testExampleMdIsAllSay() {
        let blocks = ScriptParser.parse(FixtureLoader.script("example.md"))
        XCTAssertTrue(blocks.allSatisfy { if case .say = $0 { return true }; return false })
        XCTAssertGreaterThan(blocks.count, 5)
        if case .say(let first) = blocks.first {
            XCTAssertTrue(first.contains("Welcome everyone"))
        } else {
            XCTFail("first block should be say")
        }
        XCTAssertFalse(blocks.contains { if case .say(let t) = $0 { return t.contains("#") }; return false })
    }

    func testEmptyFileHasNoContent() {
        let blocks = ScriptParser.parse("")
        XCTAssertFalse(Block.hasContent(blocks))
    }

    func testHeadingOnlyHasNoContent() {
        let blocks = ScriptParser.parse("# Title\n\n## Only heading\n\n---\n")
        XCTAssertFalse(Block.hasContent(blocks))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd macos && swift test --filter ScriptParserTests`

Expected: FAIL — `ScriptParser` not found.

- [ ] **Step 3: Implement parser with Format C + empty (enough to pass this task)**

`macos/Sources/TeleprompterCore/ScriptParser.swift`:

```swift
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
        return sayParagraphs(from: lines.joined(separator: "\n"))
    }

    private static func parseLabeled(_ markdown: String) -> [Block] {
        // Implemented in Task 4. Stub keeps Format C tests green.
        []
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd macos && swift test --filter ScriptParserTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add macos/Sources/TeleprompterCore/ScriptParser.swift macos/Tests/TeleprompterCoreTests/FixtureLoader.swift macos/Tests/TeleprompterCoreTests/ScriptParserTests.swift
git commit -m "feat: parse plain markdown scripts into say blocks"
```

---

### Task 4: ScriptParser — Format A labeled SAY/DRAW (TDD)

**Files:**
- Modify: `macos/Sources/TeleprompterCore/ScriptParser.swift`
- Modify: `macos/Tests/TeleprompterCoreTests/ScriptParserTests.swift`

- [ ] **Step 1: Add failing tests against `scripts/agent-registry.md`**

Append to `ScriptParserTests`:

```swift
    func testAgentRegistryDropsPreambleAndProductionNotes() {
        let blocks = ScriptParser.parse(FixtureLoader.script("agent-registry.md"))
        let texts = blocks.map(Self.blockText)
        XCTAssertFalse(texts.contains { $0.localizedCaseInsensitiveContains("Production notes") })
        XCTAssertFalse(texts.contains { $0.contains("Target runtime") })
        XCTAssertFalse(texts.contains { $0.contains("Board layout") })
    }

    func testAgentRegistryHasSegmentsSayAndDraw() {
        let blocks = ScriptParser.parse(FixtureLoader.script("agent-registry.md"))
        XCTAssertTrue(blocks.contains { if case .segment(let t) = $0 { return t.contains("SEGMENT 1") }; return false })
        XCTAssertTrue(blocks.contains { if case .draw(let t) = $0 { return t.contains("DRAW (left third)") && t.contains("Kubernetes node") }; return false })
        XCTAssertTrue(blocks.contains { if case .say(let t) = $0 { return t.contains("Hi Sebastian Maniak") }; return false })
    }

    func testAgentRegistryStripsBoldInsideSay() {
        let blocks = ScriptParser.parse(FixtureLoader.script("agent-registry.md"))
        let says = blocks.compactMap { if case .say(let t) = $0 { return t }; return nil }
        XCTAssertTrue(says.contains { $0.contains("suspends") })
        XCTAssertFalse(says.contains { $0.contains("**") })
    }

    func testAgentRegistrySplitsSayOnBlankLines() {
        let blocks = ScriptParser.parse(FixtureLoader.script("agent-registry.md"))
        let firstSegmentSays = blocks.drop { block in
            if case .segment(let t) = block { return !t.contains("SEGMENT 1") }
            return true
        }.prefix { if case .segment(let t) = $0 { return t.contains("SEGMENT 1") }; return true }
            .compactMap { if case .say(let t) = $0 { return t }; return nil }
        XCTAssertGreaterThan(firstSegmentSays.count, 3)
    }

    private static func blockText(_ block: Block) -> String {
        switch block {
        case .segment(let t), .say(let t), .draw(let t): return t
        }
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd macos && swift test --filter testAgentRegistry`

Expected: FAIL — `parseLabeled` returns `[]`.

- [ ] **Step 3: Implement `parseLabeled`**

Replace the `parseLabeled` stub in `ScriptParser.swift` with:

```swift
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
        return blocks
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
        line.range(of: #"^\s*\*\*DRAW"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func isSayMarker(_ line: String) -> Bool {
        line.range(of: #"^\s*\*\*SAY:\*\*"#, options: [.regularExpression, .caseInsensitive]) != nil
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd macos && swift test --filter ScriptParserTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add macos/Sources/TeleprompterCore/ScriptParser.swift macos/Tests/TeleprompterCoreTests/ScriptParserTests.swift
git commit -m "feat: parse labeled SAY/DRAW lightboard scripts"
```

---

### Task 5: ScriptParser — Format B bracket stage directions (TDD)

**Files:**
- Modify: `macos/Sources/TeleprompterCore/ScriptParser.swift`
- Modify: `macos/Tests/TeleprompterCoreTests/ScriptParserTests.swift`

- [ ] **Step 1: Add failing tests against `scripts/virtual-mcp.md`**

Append to `ScriptParserTests`:

```swift
    func testVirtualMcpDropsNonActionBrackets() {
        let blocks = ScriptParser.parse(FixtureLoader.script("virtual-mcp.md"))
        let texts = blocks.map(Self.blockText)
        XCTAssertFalse(texts.contains { $0.contains("Optional cold open") })
        XCTAssertFalse(texts.contains { $0.contains("Standard opener") })
    }

    func testVirtualMcpTreatsActionBracketsAsDraw() {
        let blocks = ScriptParser.parse(FixtureLoader.script("virtual-mcp.md"))
        let draws = blocks.compactMap { if case .draw(let t) = $0 { return t }; return nil }
        XCTAssertTrue(draws.contains { $0.localizedCaseInsensitiveContains("Draw agent box") })
        XCTAssertTrue(draws.contains { $0.localizedCaseInsensitiveContains("Write at top") })
        XCTAssertTrue(draws.contains { $0.localizedCaseInsensitiveContains("Tap the lines") })
        XCTAssertTrue(draws.contains { $0.localizedCaseInsensitiveContains("Circle the Jira") })
        XCTAssertFalse(draws.contains { $0.hasPrefix("[") })
    }

    func testVirtualMcpSpokenLinesAreSay() {
        let blocks = ScriptParser.parse(FixtureLoader.script("virtual-mcp.md"))
        let says = blocks.compactMap { if case .say(let t) = $0 { return t }; return nil }
        XCTAssertTrue(says.contains { $0.contains("Hey, I'm Sebastian") })
        XCTAssertTrue(says.contains { $0.contains("Panel 1") })
        XCTAssertTrue(Block.hasContent(blocks))
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd macos && swift test --filter testVirtualMcp`

Expected: FAIL — `parseBrackets` returns `[]`.

- [ ] **Step 3: Implement `parseBrackets`**

Replace the stub:

```swift
    private static func parseBrackets(_ markdown: String) -> [Block] {
        var blocks: [Block] = []
        for paragraph in paragraphs(in: markdown) {
            if isActionBracket(paragraph), let inner = bracketInner(paragraph) {
                let stripped = MarkdownStripper.strip(inner)
                if !stripped.isEmpty { blocks.append(.draw(text: stripped)) }
                continue
            }
            if isNonActionBracket(paragraph) {
                continue
            }
            blocks.append(contentsOf: sayParagraphs(from: paragraph))
        }
        return blocks
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd macos && swift test --filter ScriptParserTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add macos/Sources/TeleprompterCore/ScriptParser.swift macos/Tests/TeleprompterCoreTests/ScriptParserTests.swift
git commit -m "feat: parse bracket stage directions as draw cues"
```

---

### Task 6: TeleprompterEngine (TDD)

**Files:**
- Create: `macos/Sources/TeleprompterCore/TeleprompterEngine.swift`
- Create: `macos/Tests/TeleprompterCoreTests/TeleprompterEngineTests.swift`

- [ ] **Step 1: Write failing engine tests**

`macos/Tests/TeleprompterCoreTests/TeleprompterEngineTests.swift`:

```swift
import XCTest
@testable import TeleprompterCore

final class TeleprompterEngineTests: XCTestCase {
    func makeEngine() -> TeleprompterEngine {
        TeleprompterEngine(
            speed: 150,
            fontSize: 32,
            timerDuration: 10,
            viewportWidth: 1000,
            viewportHeight: 800,
            contentHeight: 4000
        )
    }

    func testPlayPauseRestart() {
        let e = makeEngine()
        XCTAssertFalse(e.playing)
        e.play()
        XCTAssertTrue(e.playing)
        e.pause()
        XCTAssertFalse(e.playing)
        e.scrollY = 100
        e.timerRemaining = 3
        e.restart()
        XCTAssertEqual(e.scrollY, 0)
        XCTAssertEqual(e.timerRemaining, 10)
        XCTAssertFalse(e.playing)
    }

    func testRestartKeepsPlayingState() {
        let e = makeEngine()
        e.play()
        e.scrollY = 50
        e.restart()
        XCTAssertTrue(e.playing)
        XCTAssertEqual(e.scrollY, 0)
    }

    func testHigherWpmMovesMorePixels() {
        let slow = makeEngine()
        slow.setSpeed(100)
        slow.play()
        slow.tick(elapsed: 1)
        let slowY = slow.scrollY

        let fast = makeEngine()
        fast.setSpeed(200)
        fast.play()
        fast.tick(elapsed: 1)
        XCTAssertGreaterThan(fast.scrollY, slowY)
        XCTAssertEqual(fast.scrollY / slowY, 2, accuracy: 0.01)
    }

    func testTickDoesNothingWhenPaused() {
        let e = makeEngine()
        e.tick(elapsed: 1)
        XCTAssertEqual(e.scrollY, 0)
    }

    func testClampAtEndAutoPauses() {
        let e = makeEngine()
        e.play()
        e.tick(elapsed: 10_000)
        let maxScroll = e.contentHeight - e.viewportHeight * 0.33
        XCTAssertEqual(e.scrollY, maxScroll, accuracy: 0.01)
        XCTAssertFalse(e.playing)
    }

    func testTimerCountsDownOnlyWhilePlaying() {
        let e = makeEngine()
        e.advanceTimer(seconds: 2)
        XCTAssertEqual(e.timerRemaining, 10)
        e.play()
        e.advanceTimer(seconds: 3)
        XCTAssertEqual(e.timerRemaining, 7)
        e.pause()
        e.advanceTimer(seconds: 3)
        XCTAssertEqual(e.timerRemaining, 7)
        e.play()
        e.advanceTimer(seconds: 100)
        XCTAssertEqual(e.timerRemaining, 0)
    }

    func testSpeedAndFontClamps() {
        let e = makeEngine()
        e.setSpeed(10)
        XCTAssertEqual(e.speed, 50)
        e.setSpeed(999)
        XCTAssertEqual(e.speed, 400)
        e.setFontSize(2)
        XCTAssertEqual(e.fontSize, 20)
        e.setFontSize(200)
        XCTAssertEqual(e.fontSize, 64)
    }

    func testProgressAndTimerDisplay() {
        let e = makeEngine()
        XCTAssertEqual(e.progress, 0)
        XCTAssertEqual(e.timerDisplay, "0:10")
        e.scrollY = e.maxScroll
        XCTAssertEqual(e.progress, 1, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd macos && swift test --filter TeleprompterEngineTests`

Expected: FAIL — `TeleprompterEngine` not found.

- [ ] **Step 3: Implement the engine**

`macos/Sources/TeleprompterCore/TeleprompterEngine.swift`:

```swift
import Foundation

public final class TeleprompterEngine {
    public static let minSpeed = 50
    public static let maxSpeed = 400
    public static let minFontSize = 20
    public static let maxFontSize = 64
    public static let minTimer = 30
    public static let maxTimer = 1800
    public static let timerStep = 30

    public private(set) var speed: Int
    public private(set) var fontSize: Int
    public private(set) var timerDuration: Int
    public var viewportWidth: Double
    public var viewportHeight: Double
    public var contentHeight: Double
    public var scrollY: Double = 0
    public private(set) var playing = false
    public private(set) var timerRemaining: Int

    public init(
        speed: Int = 150,
        fontSize: Int = 32,
        timerDuration: Int = 300,
        viewportWidth: Double = 1440,
        viewportHeight: Double = 900,
        contentHeight: Double = 0
    ) {
        self.speed = Self.clampSpeed(speed)
        self.fontSize = Self.clampFont(fontSize)
        self.timerDuration = Self.clampTimer(timerDuration)
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
        self.contentHeight = contentHeight
        self.timerRemaining = Self.clampTimer(timerDuration)
    }

    public var maxScroll: Double {
        max(0, contentHeight - viewportHeight * 0.33)
    }

    public var progress: Double {
        let maxS = maxScroll
        if maxS <= 0 { return 1 }
        return min(1, max(0, scrollY / maxS))
    }

    public var timerDisplay: String {
        let mins = timerRemaining / 60
        let secs = timerRemaining % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }

    public var pixelsPerSecond: Double {
        let avgWordLength = 5.0
        let lineHeight = Double(fontSize) * 1.7
        let charsPerLine = floor(viewportWidth / (Double(fontSize) * 0.5))
        let wordsPerLine = max(1, charsPerLine / avgWordLength)
        let linesPerSecond = (Double(speed) / 60.0) / wordsPerLine
        return linesPerSecond * lineHeight
    }

    public func play() {
        playing = true
    }

    public func pause() {
        playing = false
    }

    public func restart() {
        scrollY = 0
        timerRemaining = timerDuration
    }

    public func setSpeed(_ wpm: Int) {
        speed = Self.clampSpeed(wpm)
    }

    public func setFontSize(_ px: Int) {
        fontSize = Self.clampFont(px)
    }

    public func setTimerDuration(_ seconds: Int) {
        timerDuration = Self.clampTimer(seconds)
        timerRemaining = timerDuration
    }

    public func tick(elapsed: TimeInterval) {
        guard playing else { return }
        scrollY += pixelsPerSecond * elapsed
        if scrollY >= maxScroll {
            scrollY = maxScroll
            pause()
        }
    }

    public func advanceTimer(seconds: Int) {
        guard playing else { return }
        timerRemaining = max(0, timerRemaining - seconds)
    }

    public func nudgeScroll(_ delta: Double) {
        scrollY = min(maxScroll, max(0, scrollY + delta))
    }

    public static func clampSpeed(_ v: Int) -> Int { min(maxSpeed, max(minSpeed, v)) }
    public static func clampFont(_ v: Int) -> Int { min(maxFontSize, max(minFontSize, v)) }
    public static func clampTimer(_ v: Int) -> Int { min(maxTimer, max(minTimer, v)) }
}
```

Note: `testRestartKeepsPlayingState` expects `restart()` to **not** call `pause()`. Spec: “scroll and timer to zero; play/pause state unchanged.” The web app pauses on restart; this overlay does not. Do not call `pause()` inside `restart()`.

`testTimerCountsDownOnlyWhilePlaying` uses `advanceTimer` so tests do not wait on a real clock. The app (Task 11) calls `advanceTimer(seconds: 1)` once per second while playing.

`setTimerDuration` clamps to 30–1800. Tests use `timerDuration: 10` in `makeEngine()`. **That would clamp to 30 and break `testPlayPauseRestart`.** Pass a test-only init that does not clamp, or lower `minTimer` only in tests.

Fix: add an internal `skipTimerClamp` only for tests — cleaner: make `clampTimer` apply only in `setTimerDuration`, and let `init` accept any positive duration so tests can use 10 seconds:

Change `init` to assign `timerDuration` and `timerRemaining` from the argument without clamp. Clamp only in `setTimerDuration`. Update `makeEngine` stays at 10. `setTimerDuration` tests are not required this task.

Adjust Step 3 `init` to:

```swift
        self.speed = Self.clampSpeed(speed)
        self.fontSize = Self.clampFont(fontSize)
        self.timerDuration = timerDuration
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
        self.contentHeight = contentHeight
        self.timerRemaining = timerDuration
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd macos && swift test --filter TeleprompterEngineTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add macos/Sources/TeleprompterCore/TeleprompterEngine.swift macos/Tests/TeleprompterCoreTests/TeleprompterEngineTests.swift
git commit -m "feat: add teleprompter scroll engine and timer"
```

---

### Task 7: ScriptStore (TDD)

**Files:**
- Create: `macos/Sources/TeleprompterCore/ScriptStore.swift`
- Create: `macos/Tests/TeleprompterCoreTests/ScriptStoreTests.swift`

- [ ] **Step 1: Write failing store tests**

`macos/Tests/TeleprompterCoreTests/ScriptStoreTests.swift`:

```swift
import XCTest
@testable import TeleprompterCore

final class ScriptStoreTests: XCTestCase {
    func testListsMarkdownSorted() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "hi".write(to: dir.appendingPathComponent("b-talk.md"), atomically: true, encoding: .utf8)
        try "hi".write(to: dir.appendingPathComponent("a-talk.md"), atomically: true, encoding: .utf8)
        try "nope".write(to: dir.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let items = ScriptStore.listScripts(in: dir)
        XCTAssertEqual(items.map(\.filename), ["a-talk.md", "b-talk.md"])
        XCTAssertEqual(items[0].displayName, "A Talk")
    }

    func testEmptyFolderReturnsEmpty() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertTrue(ScriptStore.listScripts(in: dir).isEmpty)
    }

    func testResolvePrefersBookmarkThenRepo() {
        let repoScripts = FixtureLoader.repoRoot().appendingPathComponent("scripts")
        let resolved = ScriptStore.resolveScriptsFolder(
            bookmark: nil,
            executableURL: Bundle.main.bundleURL,
            fileManager: .default,
            repoWalkStart: URL(fileURLWithPath: #filePath)
        )
        XCTAssertEqual(resolved?.standardizedFileURL, repoScripts.standardizedFileURL)
    }

    func testBookmarkWinsOverRepo() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let resolved = ScriptStore.resolveScriptsFolder(
            bookmark: dir,
            executableURL: Bundle.main.bundleURL,
            fileManager: .default,
            repoWalkStart: URL(fileURLWithPath: #filePath)
        )
        XCTAssertEqual(resolved?.standardizedFileURL, dir.standardizedFileURL)
    }

    func testLoadParsesFile() throws {
        let url = FixtureLoader.repoRoot().appendingPathComponent("scripts/example.md")
        let loaded = try ScriptStore.load(url: url)
        XCTAssertEqual(loaded.filename, "example.md")
        XCTAssertTrue(Block.hasContent(loaded.blocks))
        XCTAssertGreaterThan(loaded.wordCount, 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd macos && swift test --filter ScriptStoreTests`

Expected: FAIL — `ScriptStore` not found.

- [ ] **Step 3: Implement ScriptStore**

`macos/Sources/TeleprompterCore/ScriptStore.swift`:

```swift
import Foundation

public struct ScriptItem: Equatable, Sendable, Identifiable {
    public var id: String { filename }
    public let filename: String
    public let url: URL
    public let displayName: String
    public let wordCount: Int
    public let blocks: [Block]

    public init(filename: String, url: URL, displayName: String, wordCount: Int, blocks: [Block]) {
        self.filename = filename
        self.url = url
        self.displayName = displayName
        self.wordCount = wordCount
        self.blocks = blocks
    }
}

public enum ScriptStore {
    public static func listScripts(in folder: URL) -> [ScriptItem] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: folder.path) else { return [] }
        return names
            .filter { $0.lowercased().hasSuffix(".md") }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .compactMap { name in
                let url = folder.appendingPathComponent(name)
                return try? load(url: url)
            }
    }

    public static func load(url: URL) throws -> ScriptItem {
        let text = try String(contentsOf: url, encoding: .utf8)
        let blocks = ScriptParser.parse(text)
        return ScriptItem(
            filename: url.lastPathComponent,
            url: url,
            displayName: Block.displayName(filename: url.lastPathComponent),
            wordCount: Block.spokenWordCount(blocks),
            blocks: blocks
        )
    }

    public static func resolveScriptsFolder(
        bookmark: URL?,
        executableURL: URL,
        fileManager: FileManager,
        repoWalkStart: URL
    ) -> URL? {
        if let bookmark, fileManager.fileExists(atPath: bookmark.path) {
            return bookmark
        }
        return findRepoScriptsFolder(from: repoWalkStart, fileManager: fileManager)
            ?? findRepoScriptsFolder(from: executableURL, fileManager: fileManager)
    }

    public static func findRepoScriptsFolder(from start: URL, fileManager: FileManager) -> URL? {
        var dir = start
        if !dir.hasDirectoryPath {
            dir.deleteLastPathComponent()
        }
        for _ in 0..<10 {
            let scripts = dir.appendingPathComponent("scripts")
            let git = dir.appendingPathComponent(".git")
            if fileManager.fileExists(atPath: git.path),
               fileManager.fileExists(atPath: scripts.path) {
                return scripts
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        return nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd macos && swift test --filter ScriptStoreTests`

Expected: PASS.

- [ ] **Step 5: Run the full Core suite**

Run: `cd macos && swift test`

Expected: all TeleprompterCoreTests PASS.

- [ ] **Step 6: Commit**

```bash
git add macos/Sources/TeleprompterCore/ScriptStore.swift macos/Tests/TeleprompterCoreTests/ScriptStoreTests.swift
git commit -m "feat: list and load scripts from a folder"
```

---

### Task 8: Overlay window, view, and HUD

**Files:**
- Create: `macos/Sources/TeleprompterOverlay/OverlayWindowController.swift`
- Create: `macos/Sources/TeleprompterOverlay/OverlayView.swift`
- Create: `macos/Sources/TeleprompterOverlay/ControlHUD.swift`

No automated UI tests. Keep types small so Task 9 can bind them to `AppModel`.

- [ ] **Step 1: Implement the overlay window**

`macos/Sources/TeleprompterOverlay/OverlayWindowController.swift`:

```swift
import AppKit
import SwiftUI

final class OverlayWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayWindowController: NSWindowController {
    convenience init(rootView: some View) {
        let screen = OverlayWindowController.screenUnderMouse() ?? NSScreen.main ?? NSScreen.screens[0]
        let panel = OverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        let host = NSHostingView(rootView: rootView)
        host.frame = screen.frame
        panel.contentView = host
        self.init(window: panel)
        pin(to: screen)
    }

    func setClickThrough(_ enabled: Bool) {
        window?.ignoresMouseEvents = enabled
    }

    func pin(to screen: NSScreen) {
        window?.setFrame(screen.frame, display: true)
    }

    func moveToMainIfNeeded() {
        let current = window?.screen
        if current == nil || !(NSScreen.screens.contains { $0 === current }) {
            if let main = NSScreen.main {
                pin(to: main)
            }
        }
    }

    static func screenUnderMouse() -> NSScreen? {
        let p = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) }
    }
}
```

- [ ] **Step 2: Implement OverlayView and ControlHUD**

`macos/Sources/TeleprompterOverlay/OverlayView.swift`:

```swift
import SwiftUI
import TeleprompterCore

struct OverlayView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear
                textStack
                    .offset(y: -model.engine.scrollY)
                    .padding(.horizontal, 48)
                    .frame(width: geo.size.width, alignment: .center)
                    .gesture(drag)
                topFade
                bottomFade
                guideLine
                if model.hudVisible {
                    VStack {
                        Spacer()
                        ControlHUD(model: model)
                            .padding(.bottom, 28)
                    }
                }
            }
            .onAppear {
                model.engine.viewportWidth = geo.size.width
                model.engine.viewportHeight = geo.size.height
            }
            .onChange(of: geo.size) { _, size in
                model.engine.viewportWidth = size.width
                model.engine.viewportHeight = size.height
            }
        }
        .ignoresSafeArea()
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                guard model.hudVisible else { return }
                model.engine.nudgeScroll(-value.translation.height / 20)
                model.noteInteraction()
            }
    }

    private var textStack: some View {
        VStack(alignment: .center, spacing: 28) {
            Spacer().frame(height: model.engine.viewportHeight * 0.33)
            ForEach(Array(model.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
            Spacer().frame(height: model.engine.viewportHeight * 0.5)
        }
        .background(
            GeometryReader { g in
                Color.clear.preference(key: ContentHeightKey.self, value: g.size.height)
            }
        )
        .onPreferenceChange(ContentHeightKey.self) { model.engine.contentHeight = $0 }
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .segment(let title):
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.45))
                .frame(maxWidth: 900)
        case .say(let text):
            Text(text)
                .font(.system(size: CGFloat(model.engine.fontSize), weight: .medium))
                .foregroundStyle(Color.white)
                .lineSpacing(CGFloat(model.engine.fontSize) * 0.7)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 900)
        case .draw(let text):
            Text(text)
                .font(.system(size: CGFloat(max(16, model.engine.fontSize - 10)), weight: .regular))
                .foregroundStyle(Color(red: 1, green: 0.42, blue: 0).opacity(0.85))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 820)
        }
    }

    private var guideLine: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Color.red.opacity(0.5))
                .frame(height: 2)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.33)
        }
        .allowsHitTesting(false)
    }

    private var topFade: some View {
        VStack {
            LinearGradient(colors: [Color.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 180)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var bottomFade: some View {
        VStack {
            Spacer()
            LinearGradient(colors: [.clear, Color.black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                .frame(height: 220)
        }
        .allowsHitTesting(false)
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
```

Fades use a **light** black gradient (0.55), not opaque black — this is glass, not the web app’s black screen. If the fade reads too heavy in manual QA, drop to 0.25.

`macos/Sources/TeleprompterOverlay/ControlHUD.swift`:

```swift
import SwiftUI
import TeleprompterCore

struct ControlHUD: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 16) {
            Button(model.engine.playing ? "Pause" : "Play") { model.togglePlay() }
            Button("Restart") { model.restart() }
            VStack(alignment: .leading, spacing: 2) {
                Text("SPEED \(model.engine.speed)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(model.engine.speed) },
                        set: { model.setSpeed(Int($0)) }
                    ),
                    in: Double(TeleprompterEngine.minSpeed)...Double(TeleprompterEngine.maxSpeed),
                    step: 10
                )
                .frame(width: 160)
            }
            HStack(spacing: 6) {
                Button("A−") { model.setFontSize(model.engine.fontSize - 2) }
                Text("\(model.engine.fontSize)")
                    .monospacedDigit()
                Button("A+") { model.setFontSize(model.engine.fontSize + 2) }
            }
            Text("\(Int((model.engine.progress * 100).rounded()))%")
                .monospacedDigit()
            Text(model.engine.timerDisplay)
                .monospacedDigit()
                .foregroundStyle(model.engine.timerRemaining == 0 ? Color.red : Color.primary)
                .opacity(model.engine.timerRemaining == 0 ? model.timerFlashOpacity : 1)
            Text(model.loadedScript?.displayName ?? "")
                .lineLimit(1)
                .frame(maxWidth: 180)
            Button("Close") { model.hideOverlay() }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 24)
    }
}
```

`AppModel` is created in Task 9. This task will not compile until Task 9 lands — **do not run `swift build` expecting success at the end of this task.** Next task wires it. Commit the three UI files together with Task 9 if you prefer one green commit; otherwise commit as “wip: overlay views” only if the working tree must be saved. Preferred: continue immediately into Task 9 in the same session and commit both together.

- [ ] **Step 3: Do not commit a broken tree.** Continue to Task 9.

---

### Task 9: AppModel, menu bar, and app entry

**Files:**
- Create: `macos/Sources/TeleprompterOverlay/AppModel.swift`
- Create: `macos/Sources/TeleprompterOverlay/MenuBarView.swift`
- Create: `macos/Sources/TeleprompterOverlay/App.swift`

- [ ] **Step 1: Implement AppModel**

`macos/Sources/TeleprompterOverlay/AppModel.swift`:

```swift
import AppKit
import Combine
import Foundation
import SwiftUI
import TeleprompterCore

@MainActor
final class AppModel: ObservableObject {
    @Published var scripts: [ScriptItem] = []
    @Published var loadedScript: ScriptItem?
    @Published var blocks: [Block] = []
    @Published var overlayVisible = false
    @Published var hudVisible = true
    @Published var permissionNotice: String?
    @Published var alertMessage: String?
    @Published var timerFlashOpacity: Double = 1
    @Published var engine: TeleprompterEngine

    let hudTimeout: TimeInterval = 3
    private var lastInteraction = Date()
    private var hudTicker: Timer?
    private var secondTicker: Timer?
    private var flashTicker: Timer?
    private var overlay: OverlayWindowController?
    private var hotkeys: HotkeyCenter?
    private var link: DisplayLinkDriver?
    private var defaults: UserDefaults
    private var scriptsFolder: URL?
    private var bookmarkData: Data? {
        get { defaults.data(forKey: "tp_scriptsFolderBookmark") }
        set { defaults.set(newValue, forKey: "tp_scriptsFolderBookmark") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let speed = defaults.object(forKey: "tp_speed") as? Int ?? 150
        let font = defaults.object(forKey: "tp_fontSize") as? Int ?? 32
        let timer = defaults.object(forKey: "tp_timer") as? Int ?? 300
        self.engine = TeleprompterEngine(speed: speed, fontSize: font, timerDuration: timer)
        refreshScripts()
        startHudTicker()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.overlay?.moveToMainIfNeeded() }
        }
    }

    func refreshScripts() {
        let bookmark = resolvedBookmarkURL()
        scriptsFolder = ScriptStore.resolveScriptsFolder(
            bookmark: bookmark,
            executableURL: Bundle.main.bundleURL,
            fileManager: .default,
            repoWalkStart: URL(fileURLWithPath: #filePath)
        )
        if let scriptsFolder {
            scripts = ScriptStore.listScripts(in: scriptsFolder)
        } else {
            scripts = []
        }
    }

    func loadScript(_ item: ScriptItem) {
        if !Block.hasContent(item.blocks) {
            alertMessage = "Nothing to read in this file."
            return
        }
        loadedScript = item
        blocks = item.blocks
        engine.restart()
        engine.pause()
        persistLastScript(item.url)
        showOverlay()
    }

    func loadURL(_ url: URL) {
        do {
            let item = try ScriptStore.load(url: url)
            loadScript(item)
        } catch {
            defaults.removeObject(forKey: "tp_lastScriptPath")
            alertMessage = "Could not read that file."
        }
    }

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a markdown script"
        if panel.runModal() == .OK, let url = panel.url {
            loadURL(url)
        }
    }

    func chooseScriptsFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                bookmarkData = data
            }
            refreshScripts()
        }
    }

    func togglePlay() {
        if engine.playing {
            engine.pause()
            hudVisible = true
            overlay?.setClickThrough(false)
            link?.stop()
        } else {
            engine.play()
            noteInteraction()
            link?.start()
        }
        objectWillChange.send()
    }

    func restart() {
        let wasPlaying = engine.playing
        engine.restart()
        if wasPlaying { engine.play() }
        noteInteraction()
        objectWillChange.send()
    }

    func setSpeed(_ wpm: Int) {
        engine.setSpeed(wpm)
        defaults.set(engine.speed, forKey: "tp_speed")
        noteInteraction()
        objectWillChange.send()
    }

    func setFontSize(_ px: Int) {
        engine.setFontSize(px)
        defaults.set(engine.fontSize, forKey: "tp_fontSize")
        noteInteraction()
        objectWillChange.send()
    }

    func adjustTimer(steps: Int) {
        let next = engine.timerDuration + steps * TeleprompterEngine.timerStep
        engine.setTimerDuration(TeleprompterEngine.clampTimer(next))
        defaults.set(engine.timerDuration, forKey: "tp_timer")
        objectWillChange.send()
    }

    func showOverlay() {
        if overlay == nil {
            let controller = OverlayWindowController(rootView: OverlayView(model: self))
            overlay = controller
        }
        overlay?.showWindow(nil)
        overlayVisible = true
        hudVisible = true
        overlay?.setClickThrough(false)
        hotkeys?.stop()
        let hk = HotkeyCenter(model: self)
        hk.start()
        hotkeys = hk
        if link == nil {
            link = DisplayLinkDriver { [weak self] dt in
                self?.engine.tick(elapsed: dt)
                self?.objectWillChange.send()
            }
        }
        noteInteraction()
    }

    func hideOverlay() {
        engine.pause()
        link?.stop()
        hotkeys?.stop()
        overlay?.close()
        overlay = nil
        overlayVisible = false
        hudVisible = true
    }

    func revealHUD() {
        guard overlayVisible else { return }
        hudVisible = true
        overlay?.setClickThrough(false)
        noteInteraction()
    }

    func handleEscape() {
        if hudVisible {
            if engine.playing {
                hudVisible = false
                overlay?.setClickThrough(true)
            } else {
                hideOverlay()
            }
        } else {
            hideOverlay()
        }
    }

    func noteInteraction() {
        lastInteraction = Date()
    }

    func reportHotkeyPermissionFailure() {
        if permissionNotice == nil {
            permissionNotice = "Keyboard shortcuts while other apps are focused need Input Monitoring or Accessibility. Overlay still works from this menu."
        }
    }

    private func startHudTicker() {
        hudTicker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickHUD() }
        }
        secondTicker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.engine.playing else { return }
                self.engine.advanceTimer(seconds: 1)
                if self.engine.timerRemaining == 0 { self.startFlash() }
                self.objectWillChange.send()
            }
        }
    }

    private func tickHUD() {
        guard overlayVisible, engine.playing, hudVisible else { return }
        if Date().timeIntervalSince(lastInteraction) >= hudTimeout {
            hudVisible = false
            overlay?.setClickThrough(true)
        }
    }

    private func startFlash() {
        guard flashTicker == nil else { return }
        flashTicker = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.timerFlashOpacity = (self?.timerFlashOpacity ?? 1) == 1 ? 0.2 : 1
            }
        }
    }

    private func resolvedBookmarkURL() -> URL? {
        guard let bookmarkData else { return nil }
        var stale = false
        let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        _ = url?.startAccessingSecurityScopedResource()
        return url
    }

    private func persistLastScript(_ url: URL) {
        defaults.set(url.path, forKey: "tp_lastScriptPath")
    }
}
```

`AppModel` references `HotkeyCenter` and `DisplayLinkDriver` from Task 10–11. Add stubs now so this compiles:

Create `macos/Sources/TeleprompterOverlay/HotkeyCenter.swift` stub:

```swift
import AppKit

@MainActor
final class HotkeyCenter {
    private weak var model: AppModel?
    init(model: AppModel) { self.model = model }
    func start() {}
    func stop() {}
}
```

Create `macos/Sources/TeleprompterOverlay/DisplayLinkDriver.swift` stub:

```swift
import Foundation

final class DisplayLinkDriver {
    init(onTick: @escaping (TimeInterval) -> Void) {}
    func start() {}
    func stop() {}
}
```

- [ ] **Step 2: Implement menu bar and `@main`**

`macos/Sources/TeleprompterOverlay/MenuBarView.swift`:

```swift
import SwiftUI
import TeleprompterCore

struct MenuBarView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        if let notice = model.permissionNotice {
            Text(notice)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 280)
        }
        if let alert = model.alertMessage {
            Text(alert)
            Button("OK") { model.alertMessage = nil }
        }
        if model.scripts.isEmpty {
            Text("No scripts found")
        } else {
            ForEach(model.scripts) { item in
                Button("\(item.displayName) · \(item.wordCount) words") {
                    model.loadScript(item)
                }
            }
        }
        Divider()
        Button("Open file…") { model.openFile() }
        Button("Choose scripts folder…") { model.chooseScriptsFolder() }
        Divider()
        if model.loadedScript != nil {
            if !model.overlayVisible {
                Button("Show overlay") { model.showOverlay() }
            }
            Button(model.engine.playing ? "Pause" : "Start") { model.togglePlay() }
        }
        Menu("Timer \(model.engine.timerDisplay)") {
            Button("+30s") { model.adjustTimer(steps: 1) }
            Button("−30s") { model.adjustTimer(steps: -1) }
        }
        Divider()
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }
}
```

`macos/Sources/TeleprompterOverlay/App.swift`:

```swift
import AppKit
import SwiftUI

@main
struct TeleprompterOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Teleprompter", systemImage: "text.viewfinder") {
            MenuBarView()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
```

`NSApplication` in `MenuBarView` requires `import AppKit` — add it.

- [ ] **Step 3: Build**

Run: `cd macos && swift build`

Expected: build succeeds. Warnings acceptable; errors not.

- [ ] **Step 4: Commit Tasks 8–9**

```bash
git add macos/Sources/TeleprompterOverlay
git commit -m "feat: add overlay window, HUD, and menu bar extra"
```

---

### Task 10: Hotkeys and hybrid click-through

**Files:**
- Modify: `macos/Sources/TeleprompterOverlay/HotkeyCenter.swift`

- [ ] **Step 1: Replace the HotkeyCenter stub**

```swift
import AppKit
import Carbon.HIToolbox

@MainActor
final class HotkeyCenter {
    private weak var model: AppModel?
    private var localKey: Any?
    private var globalKey: Any?
    private var globalMouse: Any?

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        localKey = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handle(event) == true { return nil }
            return event
        }
        globalKey = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handle(event)
        }
        globalMouse = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.model?.revealHUD()
        }
        if globalKey == nil {
            model?.reportHotkeyPermissionFailure()
        }
    }

    func stop() {
        if let localKey { NSEvent.removeMonitor(localKey) }
        if let globalKey { NSEvent.removeMonitor(globalKey) }
        if let globalMouse { NSEvent.removeMonitor(globalMouse) }
        localKey = nil
        globalKey = nil
        globalMouse = nil
    }

    @discardableResult
    private func handle(_ event: NSEvent) -> Bool {
        guard let model, model.overlayVisible else { return false }
        if event.modifierFlags.contains(.command) { return false }

        switch event.keyCode {
        case UInt16(kVK_Space):
            model.revealHUD()
            model.togglePlay()
            return true
        case UInt16(kVK_UpArrow):
            model.setSpeed(model.engine.speed + 10)
            model.revealHUD()
            return true
        case UInt16(kVK_DownArrow):
            model.setSpeed(model.engine.speed - 10)
            model.revealHUD()
            return true
        case UInt16(kVK_ANSI_Equal), UInt16(kVK_ANSI_KeypadPlus):
            model.setFontSize(model.engine.fontSize + 2)
            model.revealHUD()
            return true
        case UInt16(kVK_ANSI_Minus), UInt16(kVK_ANSI_KeypadMinus):
            model.setFontSize(model.engine.fontSize - 2)
            model.revealHUD()
            return true
        case UInt16(kVK_ANSI_R):
            model.restart()
            model.revealHUD()
            return true
        case UInt16(kVK_Escape):
            model.handleEscape()
            return true
        default:
            return false
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `cd macos && swift build`

Expected: success.

- [ ] **Step 3: Commit**

```bash
git add macos/Sources/TeleprompterOverlay/HotkeyCenter.swift
git commit -m "feat: add overlay hotkeys and mouse-reveal HUD"
```

---

### Task 11: Display-link driver

**Files:**
- Modify: `macos/Sources/TeleprompterOverlay/DisplayLinkDriver.swift`

- [ ] **Step 1: Replace the stub with CADisplayLink**

```swift
import AppKit
import QuartzCore

final class DisplayLinkDriver {
    private var link: CADisplayLink?
    private var last: CFTimeInterval?
    private let onTick: (TimeInterval) -> Void

    init(onTick: @escaping (TimeInterval) -> Void) {
        self.onTick = onTick
    }

    func start() {
        stop()
        last = nil
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        last = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        let now = link.timestamp
        if let last {
            onTick(now - last)
        }
        last = now
    }

    deinit { stop() }
}
```

If `CADisplayLink(target:selector:)` is unavailable on the SDK in use, fall back to:

```swift
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.onTick(1.0 / 60.0)
        }
        RunLoop.main.add(timer, forMode: .common)
```

Prefer CADisplayLink. Document the fallback in the commit body only if used.

- [ ] **Step 2: Build and re-run Core tests**

Run: `cd macos && swift test && swift build`

Expected: tests PASS, build succeeds.

- [ ] **Step 3: Commit**

```bash
git add macos/Sources/TeleprompterOverlay/DisplayLinkDriver.swift
git commit -m "feat: drive scroll with CADisplayLink"
```

---

### Task 12: README and launch notes

**Files:**
- Create: `macos/README.md`

- [ ] **Step 1: Write the README**

```markdown
# Teleprompter Overlay

Native macOS glass teleprompter. Reads `scripts/*.md` from this repo (or any `.md` file) and scrolls SAY / DRAW on a transparent always-on-top overlay.

## Requirements

- macOS 14+
- Xcode CLT / Swift 5.9+

## Test

```bash
cd macos
swift test
```

## Run

```bash
cd macos
swift run TeleprompterOverlay
```

A teleprompter icon appears in the menu bar (no Dock tile). Pick a script. Space play/pauses. Mouse move shows the HUD. While playing with the HUD hidden, clicks pass through to the app behind.

If global hotkeys do not work while another app is focused, grant Input Monitoring or Accessibility to the `swift` / `TeleprompterOverlay` binary under System Settings → Privacy & Security.

## Manual QA

1. Overlay is transparent over Safari or OBS.
2. Playing + HUD hidden: clicks reach the app behind.
3. Mouse move or Space shows the HUD; clicks hit the HUD.
4. After ~3s idle while playing, HUD hides and click-through returns.
5. Menu lists `scripts/*.md`; Open file… loads a file outside the repo.
6. SAY is large/white; DRAW is smaller, dim, orange.
7. Esc hides HUD, then hides overlay; menu-bar extra remains.
```

- [ ] **Step 2: Commit**

```bash
git add macos/README.md
git commit -m "docs: add macOS overlay build and QA notes"
```

---

### Task 13: Manual verification (required before v1 is done)

- [ ] **Step 1: Run the app**

`cd macos && swift run TeleprompterOverlay`

- [ ] **Step 2: Walk the spec checklist**

1. Overlay is transparent over a browser or OBS.
2. While playing with HUD hidden, clicks reach the app behind.
3. Mouse move or Space shows the HUD; clicks then hit the HUD, not the app behind.
4. After ~3 seconds idle while playing, HUD hides and click-through returns.
5. Menu lists `scripts/*.md`; Open file… loads a file outside the repo.
6. SAY is large/white; DRAW is smaller, dim, orange.
7. Esc hides HUD, then hides overlay; menu-bar extra remains.
8. `agent-registry.md`: no production notes on glass; SEGMENT labels appear; DRAW orange.
9. `virtual-mcp.md`: `[Draw …]` is orange cue; spoken lines are white; cold-open bracket is absent.
10. Timer flashes in HUD at 0:00 and does not stop scroll.
11. Unplugging a display (if you can) moves the overlay to the main screen.

- [ ] **Step 3: Fix any failures in the owning file, re-run `swift test`, commit the fix.**

Do not mark v1 done until the checklist passes on a real Mac.

---

## Self-review vs spec

| Spec requirement | Task |
|---|---|
| Full-screen transparent always-on-top overlay | 8 |
| Hybrid click-through | 9 (`tickHUD`) + 10 |
| SAY large / DRAW quieter orange | 8 `OverlayView` |
| `scripts/` + Open file… + Choose folder | 7, 9 |
| Menu-bar extra, no Dock | 9 `AppDelegate` |
| HUD controls listed in spec | 8 `ControlHUD` |
| Hotkeys table | 10 |
| Format A / B / C parser | 3–5 |
| Production notes not shown | 4 (`production notes` heading skipped) |
| Engine WPM math matches `teleprompter.js` | 6 `pixelsPerSecond` |
| Timer only while playing; flash at 0; scroll continues | 6, 9 |
| Settings in UserDefaults | 9 |
| Permission notice | 9 + 10 |
| Display unplug → main screen | 9 observer |
| Parser + engine automated tests | 2–7 |
| Manual QA | 13 |
| Web app untouched | all tasks stay under `macos/` |

No placeholders left. Types are consistent: `Block`, `ScriptItem`, `ScriptParser.parse`, `TeleprompterEngine`, `ScriptStore`, `AppModel`, `OverlayWindowController`, `HotkeyCenter`, `DisplayLinkDriver`.

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

    func testAgentRegistryDropsPreambleAndProductionNotes() {
        let blocks = ScriptParser.parse(FixtureLoader.script("agentsubstrate.md"))
        let texts = blocks.map(Self.blockText)
        XCTAssertFalse(texts.contains { $0.localizedCaseInsensitiveContains("Production notes") })
        XCTAssertFalse(texts.contains { $0.contains("Target runtime") })
        XCTAssertFalse(texts.contains { $0.contains("Board layout") })
    }

    func testAgentRegistryHasSegmentsSayAndDraw() {
        let blocks = ScriptParser.parse(FixtureLoader.script("agentsubstrate.md"))
        XCTAssertTrue(blocks.contains { if case .segment(let t) = $0 { return t.contains("SEGMENT 1") }; return false })
        XCTAssertTrue(blocks.contains { if case .draw(let t) = $0 { return t.contains("DRAW (left third)") && t.contains("Kubernetes node") }; return false })
        XCTAssertTrue(blocks.contains { if case .say(let t) = $0 { return t.contains("Hi Sebastian Maniak") }; return false })
    }

    func testAgentRegistryStripsBoldInsideSay() {
        let blocks = ScriptParser.parse(FixtureLoader.script("agentsubstrate.md"))
        let says = blocks.compactMap { if case .say(let t) = $0 { return t }; return nil }
        XCTAssertTrue(says.contains { $0.contains("suspends") })
        XCTAssertFalse(says.contains { $0.contains("**") })
    }

    func testAgentRegistrySplitsSayOnBlankLines() {
        let blocks = ScriptParser.parse(FixtureLoader.script("agentsubstrate.md"))
        let firstSegmentSays = blocks.drop { block in
            if case .segment(let t) = block { return !t.contains("SEGMENT 1") }
            return true
        }.prefix { if case .segment(let t) = $0 { return t.contains("SEGMENT 1") }; return true }
            .compactMap { if case .say(let t) = $0 { return t }; return nil }
        XCTAssertGreaterThan(firstSegmentSays.count, 3)
    }

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

    private static func blockText(_ block: Block) -> String {
        switch block {
        case .segment(let t), .say(let t), .draw(let t): return t
        }
    }
}

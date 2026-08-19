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

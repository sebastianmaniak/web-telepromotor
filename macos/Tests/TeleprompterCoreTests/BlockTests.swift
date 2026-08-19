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

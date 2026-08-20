import XCTest
@testable import TeleprompterCore

final class BlockTests: XCTestCase {
    func testSpokenWordCountIgnoresDrawAndSegment() {
        let blocks: [Block] = [
            .segment(title: "SEGMENT 1"),
            .draw(text: "DRAW (left): a box"),
            .say(text: "Hello there friend"),
            .say(text: "One two")
        ]
        XCTAssertEqual(Block.spokenWordCount(blocks), 5)
    }

    func testDisplayNameTitleCasesFilename() {
        XCTAssertEqual(Block.displayName(filename: "agent-registry.md"), "Agent Registry")
        XCTAssertEqual(Block.displayName(filename: "virtual_mcp.md"), "Virtual Mcp")
    }

    func testHasSpokenOrDrawContent() {
        XCTAssertFalse(Block.hasContent([.segment(title: "Only")]))
        XCTAssertTrue(Block.hasContent([.say(text: "Hi")]))
        XCTAssertTrue(Block.hasContent([.draw(text: "Draw a box")]))
    }
}

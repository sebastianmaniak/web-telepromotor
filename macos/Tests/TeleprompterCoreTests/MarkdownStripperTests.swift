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

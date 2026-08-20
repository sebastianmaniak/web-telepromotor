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

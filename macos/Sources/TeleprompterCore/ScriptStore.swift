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

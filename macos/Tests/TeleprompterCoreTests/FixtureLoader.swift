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

import Foundation
import AppKCodeShared

public final class CurrentFileContextProvider: ContextProvider, @unchecked Sendable {
    public let source: ContextSource = .currentFile
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func gather(context: ContextRequest) async throws -> [ContextItem] {
        guard let currentFile = context.currentFile else {
            return []
        }
        guard fileManager.fileExists(atPath: currentFile.path) else {
            return []
        }
        let content = try String(contentsOf: currentFile, encoding: .utf8)
        let metadata = ContextMetadata(
            language: languageForFile(currentFile),
            fileSize: content.count,
            modifiedAt: nil,
            symbolName: nil,
            diagnosticCount: nil
        )
        let item = ContextItem(
            source: .currentFile,
            path: currentFile,
            range: nil,
            content: content,
            metadata: metadata
        )
        return [item]
    }

    private func languageForFile(_ url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        let map: [String: String] = [
            "swift": "swift", "py": "python", "js": "javascript", "ts": "typescript",
            "go": "go", "rs": "rust", "java": "java", "kt": "kotlin",
            "c": "c", "cpp": "cpp", "h": "c", "hpp": "cpp",
            "json": "json", "yaml": "yaml", "yml": "yaml", "md": "markdown",
        ]
        return map[ext]
    }
}
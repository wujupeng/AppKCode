import Foundation
import AppKCodeShared

public final class WorkspaceContextProvider: ContextProvider, @unchecked Sendable {
    public let source: ContextSource = .workspace
    private let fileManager: FileManager
    private let maxEntries: Int
    private let ignoredDirectories: Set<String>

    public init(
        fileManager: FileManager = .default,
        maxEntries: Int = 200,
        ignoredDirectories: Set<String> = [".git", ".build", "build", ".swiftpm", "DerivedData", ".appkcode"]
    ) {
        self.fileManager = fileManager
        self.maxEntries = maxEntries
        self.ignoredDirectories = ignoredDirectories
    }

    public func gather(context: ContextRequest) async throws -> [ContextItem] {
        var entries: [String] = []
        collectEntries(at: context.projectRoot, entries: &entries, depth: 0, maxDepth: 3)
        let content = entries.joined(separator: "\n")
        let item = ContextItem(
            source: .workspace,
            path: context.projectRoot,
            range: nil,
            content: content,
            metadata: ContextMetadata(
                language: nil,
                fileSize: content.count,
                modifiedAt: nil,
                symbolName: nil,
                diagnosticCount: nil
            )
        )
        return [item]
    }

    private func collectEntries(at url: URL, entries: inout [String], depth: Int, maxDepth: Int) {
        guard depth <= maxDepth, entries.count < maxEntries else { return }
        guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]) else { return }
        let isDir = resourceValues.isDirectory ?? false
        guard isDir else {
            entries.append(url.relativePath)
            return
        }
        guard let children = try? fileManager.contentsOfDirectory(atPath: url.path) else { return }
        for child in children.sorted() {
            if ignoredDirectories.contains(child) { continue }
            if entries.count >= maxEntries { break }
            let childURL = url.appendingPathComponent(child)
            collectEntries(at: childURL, entries: &entries, depth: depth + 1, maxDepth: maxDepth)
        }
    }
}
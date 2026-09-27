import Foundation
import AppKCodeShared

public final class ContextBuilder: @unchecked Sendable {
    public init() {}

    public func buildContext(prompt: String, currentFile: EditorDocumentState?, projectRoot: URL) -> ContextPackage {
        var messages: [ContextMessage] = []

        messages.append(ContextMessage(role: .system, content: "You are AppKCode Agent, an AI engineering assistant. You help with code review, testing, bug fixing, and project analysis."))

        if let file = currentFile {
            messages.append(ContextMessage(role: .system, content: "Current file: \(file.url.lastPathComponent)\n```\n\(file.content)\n```"))
        }

        let fileList = listProjectFiles(at: projectRoot, maxDepth: 3)
        let fileListStr = fileList.prefix(200).map { $0.path }.joined(separator: "\n")
        messages.append(ContextMessage(role: .system, content: "Project files:\n\(fileListStr)"))

        messages.append(ContextMessage(role: .user, content: prompt))

        return ContextPackage(
            prompt: prompt,
            currentFileContent: currentFile?.content,
            currentFileURL: currentFile?.url,
            projectFileList: fileList,
            messages: messages
        )
    }

    private func listProjectFiles(at url: URL, maxDepth: Int, currentDepth: Int = 0) -> [URL] {
        guard currentDepth <= maxDepth else { return [] }
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey]
        guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles]) else {
            return []
        }
        var files: [URL] = []
        for item in contents {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                files.append(contentsOf: listProjectFiles(at: item, maxDepth: maxDepth, currentDepth: currentDepth + 1))
            } else {
                files.append(item)
            }
        }
        return files
    }
}
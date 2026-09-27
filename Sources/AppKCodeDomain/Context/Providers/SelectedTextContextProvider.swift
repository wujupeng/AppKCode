import Foundation
import AppKCodeShared

public final class SelectedTextContextProvider: ContextProvider, @unchecked Sendable {
    public let source: ContextSource = .selectedText
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func gather(context: ContextRequest) async throws -> [ContextItem] {
        guard let currentFile = context.currentFile,
              let selection = context.selection else {
            return []
        }
        guard fileManager.fileExists(atPath: currentFile.path) else {
            return []
        }
        let content = try String(contentsOf: currentFile, encoding: .utf8)
        let lines = content.components(separatedBy: "\n")
        guard selection.startLine >= 0 && selection.startLine < lines.count else {
            return []
        }
        let endLine = min(selection.endLine, lines.count - 1)
        let selectedLines = Array(lines[selection.startLine...endLine])
        let selectedText = selectedLines.joined(separator: "\n")
        let metadata = ContextMetadata(
            language: nil,
            fileSize: selectedText.count,
            modifiedAt: nil,
            symbolName: nil,
            diagnosticCount: nil
        )
        let item = ContextItem(
            source: .selectedText,
            path: currentFile,
            range: selection,
            content: selectedText,
            metadata: metadata
        )
        return [item]
    }
}
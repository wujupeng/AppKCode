import Foundation
import AppKCodeShared

public final class OpenTabsContextProvider: ContextProvider, @unchecked Sendable {
    public let source: ContextSource = .openTabs
    private let fileManager: FileManager
    private let maxLinesPerTab: Int

    public init(fileManager: FileManager = .default, maxLinesPerTab: Int = 50) {
        self.fileManager = fileManager
        self.maxLinesPerTab = maxLinesPerTab
    }

    public func gather(context: ContextRequest) async throws -> [ContextItem] {
        var items: [ContextItem] = []
        for tabURL in context.openTabs {
            guard fileManager.fileExists(atPath: tabURL.path) else {
                continue
            }
            guard let content = try? String(contentsOf: tabURL, encoding: .utf8) else {
                continue
            }
            let lines = content.components(separatedBy: "\n")
            let summaryLines = Array(lines.prefix(maxLinesPerTab))
            let summary = summaryLines.joined(separator: "\n")
            let metadata = ContextMetadata(
                language: nil,
                fileSize: content.count,
                modifiedAt: nil,
                symbolName: nil,
                diagnosticCount: nil
            )
            let item = ContextItem(
                source: .openTabs,
                path: tabURL,
                range: nil,
                content: summary,
                metadata: metadata
            )
            items.append(item)
            if items.count >= context.budget.maxItems {
                break
            }
        }
        return items
    }
}
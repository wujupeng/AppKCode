import Foundation
import AppKCodeShared

public final class GitDiffContextProvider: ContextProvider, @unchecked Sendable {
    public let source: ContextSource = .gitDiff
    private let diffProvider: (@Sendable (URL) async throws -> String)?

    public init(diffProvider: (@Sendable (URL) async throws -> String)? = nil) {
        self.diffProvider = diffProvider
    }

    public func gather(context: ContextRequest) async throws -> [ContextItem] {
        guard let provider = diffProvider else {
            return []
        }
        let diffContent = try await provider(context.projectRoot)
        guard !diffContent.isEmpty else {
            return []
        }
        let item = ContextItem(
            source: .gitDiff,
            path: context.projectRoot,
            range: nil,
            content: diffContent,
            metadata: ContextMetadata(
                language: nil,
                fileSize: diffContent.count,
                modifiedAt: nil,
                symbolName: nil,
                diagnosticCount: nil
            )
        )
        return [item]
    }
}
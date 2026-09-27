import Foundation
import AppKCodeShared

public final class BuildTestResultsContextProvider: ContextProvider, @unchecked Sendable {
    public let source: ContextSource = .buildTestResults
    private let resultsProvider: (@Sendable (URL) async throws -> String)?

    public init(resultsProvider: (@Sendable (URL) async throws -> String)? = nil) {
        self.resultsProvider = resultsProvider
    }

    public func gather(context: ContextRequest) async throws -> [ContextItem] {
        guard let provider = resultsProvider else {
            return []
        }
        let resultsContent = try await provider(context.projectRoot)
        guard !resultsContent.isEmpty else {
            return []
        }
        let item = ContextItem(
            source: .buildTestResults,
            path: context.projectRoot,
            range: nil,
            content: resultsContent,
            metadata: ContextMetadata(
                language: nil,
                fileSize: resultsContent.count,
                modifiedAt: nil,
                symbolName: nil,
                diagnosticCount: nil
            )
        )
        return [item]
    }
}
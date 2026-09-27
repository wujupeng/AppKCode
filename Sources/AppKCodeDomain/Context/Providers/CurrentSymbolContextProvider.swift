import Foundation
import AppKCodeShared

public final class CurrentSymbolContextProvider: ContextProvider, @unchecked Sendable {
    public let source: ContextSource = .currentSymbol
    private let symbolProvider: (@Sendable (URL, SourceRange?) async throws -> String?)?

    public init(symbolProvider: (@Sendable (URL, SourceRange?) async throws -> String?)? = nil) {
        self.symbolProvider = symbolProvider
    }

    public func gather(context: ContextRequest) async throws -> [ContextItem] {
        guard let currentFile = context.currentFile else {
            return []
        }
        guard let provider = symbolProvider else {
            return []
        }
        let symbolContent = try await provider(currentFile, context.selection)
        guard let content = symbolContent, !content.isEmpty else {
            return []
        }
        let item = ContextItem(
            source: .currentSymbol,
            path: currentFile,
            range: context.selection,
            content: content,
            metadata: ContextMetadata(symbolName: nil)
        )
        return [item]
    }
}
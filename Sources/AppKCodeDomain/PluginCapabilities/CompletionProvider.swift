import Foundation

public protocol CompletionProvider: PluginCapability {
    func provideCompletions(at position: LSPPosition, in document: TextDocumentIdentifier) async throws -> [CompletionItem]
}
import Foundation

public struct ContextItem: Sendable, Equatable, Codable {
    public let id: UUID
    public let source: ContextSource
    public let path: URL?
    public let range: SourceRange?
    public var content: String
    public let metadata: ContextMetadata
    public let tokenEstimate: Int

    public init(
        id: UUID = UUID(),
        source: ContextSource,
        path: URL? = nil,
        range: SourceRange? = nil,
        content: String,
        metadata: ContextMetadata = .empty,
        tokenEstimate: Int? = nil
    ) {
        self.id = id
        self.source = source
        self.path = path
        self.range = range
        self.content = content
        self.metadata = metadata
        self.tokenEstimate = tokenEstimate ?? ContextItem.estimateTokens(content)
    }

    public static func estimateTokens(_ text: String) -> Int {
        return max(1, text.count / 4)
    }
}
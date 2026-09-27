import Foundation

public struct ContextBudget: Sendable, Equatable, Codable {
    public let maxTokens: Int
    public let maxItems: Int
    public let truncationStrategy: TruncationStrategy

    public init(
        maxTokens: Int = 8192,
        maxItems: Int = 20,
        truncationStrategy: TruncationStrategy = .headTail
    ) {
        self.maxTokens = maxTokens
        self.maxItems = maxItems
        self.truncationStrategy = truncationStrategy
    }
}

public enum TruncationStrategy: String, Sendable, Equatable, Codable {
    case head
    case tail
    case headTail
    case semantic
}
import Foundation

public struct ChatMessage: Sendable, Equatable, Codable {
    public let id: UUID
    public let role: ChatRole
    public var content: String
    public let createdAt: ISO8601Timestamp
    public let metadata: ChatMessageMetadata

    public init(
        id: UUID = UUID(),
        role: ChatRole,
        content: String,
        createdAt: ISO8601Timestamp = ISO8601Timestamp(),
        metadata: ChatMessageMetadata = .empty
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.metadata = metadata
    }
}

public enum ChatRole: String, Sendable, Equatable, Codable {
    case user
    case assistant
    case system
}

public struct ChatMessageMetadata: Sendable, Equatable, Codable {
    public let tokenUsage: TokenUsage?
    public let finishReason: String?
    public let modelProviderID: String?

    public init(
        tokenUsage: TokenUsage? = nil,
        finishReason: String? = nil,
        modelProviderID: String? = nil
    ) {
        self.tokenUsage = tokenUsage
        self.finishReason = finishReason
        self.modelProviderID = modelProviderID
    }

    public static let empty = ChatMessageMetadata()
}
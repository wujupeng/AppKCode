import Foundation

public struct ChatSession: Sendable, Equatable, Codable {
    public let id: UUID
    public let projectRoot: URL
    public var messages: [ChatMessage]
    public var status: ChatSessionStatus
    public let createdAt: ISO8601Timestamp

    public init(
        id: UUID = UUID(),
        projectRoot: URL,
        messages: [ChatMessage] = [],
        status: ChatSessionStatus = .idle,
        createdAt: ISO8601Timestamp = ISO8601Timestamp()
    ) {
        self.id = id
        self.projectRoot = projectRoot
        self.messages = messages
        self.status = status
        self.createdAt = createdAt
    }
}

public enum ChatSessionStatus: String, Sendable, Equatable, Codable {
    case active
    case streaming
    case idle
    case error
    case cancelled
}
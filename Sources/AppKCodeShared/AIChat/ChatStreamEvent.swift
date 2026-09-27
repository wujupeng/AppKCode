import Foundation

public enum ChatStreamEvent: Sendable, Equatable {
    case delta(String)
    case complete(ChatMessage)
    case error(ChatError)
    case cancelled
}
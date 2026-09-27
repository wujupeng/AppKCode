import Foundation

public struct ChatInferenceRequest: Sendable, Equatable {
    public let messages: [ChatMessage]
    public let context: [ContextItem]
    public let taskType: TaskType
    public let stream: Bool
    public let maxTokens: Int?
    public let temperature: Double?

    public init(
        messages: [ChatMessage],
        context: [ContextItem] = [],
        taskType: TaskType = .codeReview,
        stream: Bool = false,
        maxTokens: Int? = nil,
        temperature: Double? = nil
    ) {
        self.messages = messages
        self.context = context
        self.taskType = taskType
        self.stream = stream
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}

public struct ChatInferenceResponse: Sendable, Equatable {
    public let message: ChatMessage
    public let finishReason: FinishReason
    public let usage: TokenUsage?

    public init(
        message: ChatMessage,
        finishReason: FinishReason = .stop,
        usage: TokenUsage? = nil
    ) {
        self.message = message
        self.finishReason = finishReason
        self.usage = usage
    }
}

public struct StreamingChunk: Sendable, Equatable {
    public let delta: String
    public let finishReason: FinishReason?

    public init(delta: String, finishReason: FinishReason? = nil) {
        self.delta = delta
        self.finishReason = finishReason
    }
}

public enum FinishReason: String, Sendable, Equatable {
    case stop
    case length
    case contentFilter
    case toolCall
    case error
}
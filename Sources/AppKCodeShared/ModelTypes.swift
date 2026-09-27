import Foundation

public enum TaskType: Sendable, Equatable, Hashable {
    case codeCompletion
    case codeReview
    case intentRecognition
    case reportGeneration
    case embedding
}

public enum EndpointMode: Sendable, Equatable {
    case local
    case cloud
}

public struct ModelEndpoint: Sendable, Equatable {
    public let url: URL
    public let mode: EndpointMode
    public init(url: URL, mode: EndpointMode) {
        self.url = url
        self.mode = mode
    }
}

public struct InferenceRequest: Sendable, Equatable {
    public let messages: [ContextMessage]
    public let taskType: TaskType
    public let maxTokens: Int?
    public let temperature: Double?
    public let stream: Bool
    public init(messages: [ContextMessage], taskType: TaskType, maxTokens: Int? = nil, temperature: Double? = nil, stream: Bool = false) {
        self.messages = messages
        self.taskType = taskType
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.stream = stream
    }
}

public struct InferenceResponse: Sendable, Equatable {
    public let content: String
    public let finishReason: String?
    public let usage: TokenUsage?
    public init(content: String, finishReason: String? = nil, usage: TokenUsage? = nil) {
        self.content = content
        self.finishReason = finishReason
        self.usage = usage
    }
}

public struct TokenUsage: Sendable, Equatable {
    public let promptTokens: Int
    public let completionTokens: Int
    public init(promptTokens: Int, completionTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
    }
}

public enum EvidenceKind: Sendable, Equatable {
    case commandOutput
    case fileContent
    case testReport
    case commitHash
    case modelResponse
    case approvalDecision
}

public struct EvidenceRecord: Sendable, Equatable {
    public let evidenceID: String
    public let sessionID: AgentSessionID
    public let kind: EvidenceKind
    public let content: String
    public let contentHash: SHA256
    public let capturedAt: ISO8601Timestamp
    public init(evidenceID: String = UUID().uuidString, sessionID: AgentSessionID, kind: EvidenceKind, content: String, contentHash: SHA256, capturedAt: ISO8601Timestamp = ISO8601Timestamp()) {
        self.evidenceID = evidenceID
        self.sessionID = sessionID
        self.kind = kind
        self.content = content
        self.contentHash = contentHash
        self.capturedAt = capturedAt
    }
}

public struct EvidenceChain: Sendable, Equatable {
    public let sessionID: AgentSessionID
    public let records: [EvidenceRecord]
    public init(sessionID: AgentSessionID, records: [EvidenceRecord] = []) {
        self.sessionID = sessionID
        self.records = records
    }
}
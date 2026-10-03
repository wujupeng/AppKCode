import Foundation

// MARK: - Streaming Capability Result (TASK-001.1, REQ-037)

public struct StreamingCapabilityResult: Sendable, Codable, Equatable {
    public let streamID: UUID
    public let chunkIndex: Int
    public let chunkData: AnyCodableValue
    public let isFinal: Bool
    public let totalChunks: Int?
    public let error: StreamingError?

    public init(
        streamID: UUID = UUID(),
        chunkIndex: Int,
        chunkData: AnyCodableValue,
        isFinal: Bool,
        totalChunks: Int? = nil,
        error: StreamingError? = nil
    ) {
        self.streamID = streamID
        self.chunkIndex = chunkIndex
        self.chunkData = chunkData
        self.isFinal = isFinal
        self.totalChunks = totalChunks
        self.error = error
    }
}

// MARK: - Streaming Error (TASK-001.2)

public struct StreamingError: Sendable, Codable, Equatable {
    public let code: Int32
    public let message: String
    public let recoverable: Bool

    public init(code: Int32, message: String, recoverable: Bool) {
        self.code = code
        self.message = message
        self.recoverable = recoverable
    }
}
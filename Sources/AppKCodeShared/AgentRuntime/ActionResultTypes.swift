import Foundation

// MARK: - Tool Output (TASK-006.2)

public struct ToolOutput: Sendable, Codable, Equatable {
    public let data: Data
    public let text: String?
    public let structured: [String: ToolValue]?

    public init(data: Data = Data(), text: String? = nil, structured: [String: ToolValue]? = nil) {
        self.data = data
        self.text = text
        self.structured = structured
    }

    public init(text: String) {
        self.data = Data(text.utf8)
        self.text = text
        self.structured = nil
    }
}

// MARK: - Failure Source (TASK-006.3)

public enum FailureSource: String, Sendable, Codable, Equatable {
    case toolInternal
    case authorizationRejected
    case serviceUnavailable
    case invalidArguments
    case underlyingError
}

// MARK: - Action Result Success (TASK-006.2)

public struct ActionResultSuccess: Sendable, Codable, Equatable {
    public let output: ToolOutput
    public let evidenceID: EvidenceRecordID
    public let durationSeconds: Double
    public let completedAt: ISO8601Timestamp

    public init(output: ToolOutput, evidenceID: EvidenceRecordID, durationSeconds: Double, completedAt: ISO8601Timestamp = ISO8601Timestamp()) {
        self.output = output
        self.evidenceID = evidenceID
        self.durationSeconds = durationSeconds
        self.completedAt = completedAt
    }
}

// MARK: - Action Result Failure (TASK-006.3)

public struct ActionResultFailure: Sendable, Codable, Equatable {
    public let code: Int
    public let message: String
    public let source: FailureSource
    public let evidenceID: EvidenceRecordID?
    public let occurredAt: ISO8601Timestamp

    public init(code: Int, message: String, source: FailureSource, evidenceID: EvidenceRecordID? = nil, occurredAt: ISO8601Timestamp = ISO8601Timestamp()) {
        self.code = code
        self.message = message
        self.source = source
        self.evidenceID = evidenceID
        self.occurredAt = occurredAt
    }
}

// MARK: - Action Result Timeout (TASK-006.4)

public struct ActionResultTimeout: Sendable, Codable, Equatable {
    public let timeoutDurationSeconds: Double
    public let occurredAt: ISO8601Timestamp

    public init(timeoutDurationSeconds: Double, occurredAt: ISO8601Timestamp = ISO8601Timestamp()) {
        self.timeoutDurationSeconds = timeoutDurationSeconds
        self.occurredAt = occurredAt
    }
}

// MARK: - Action Result Cancel (TASK-006.4)

public struct ActionResultCancel: Sendable, Codable, Equatable {
    public let reason: String
    public let occurredAt: ISO8601Timestamp

    public init(reason: String, occurredAt: ISO8601Timestamp = ISO8601Timestamp()) {
        self.reason = reason
        self.occurredAt = occurredAt
    }
}

// MARK: - Action Result (TASK-006.1)

public enum ActionResult: Sendable, Codable, Equatable {
    case success(ActionResultSuccess)
    case failure(ActionResultFailure)
    case timedOut(ActionResultTimeout)
    case cancelled(ActionResultCancel)

    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    public var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }

    public var isTimedOut: Bool {
        if case .timedOut = self { return true }
        return false
    }

    public var isCancelled: Bool {
        if case .cancelled = self { return true }
        return false
    }
}

// MARK: - Action Result Snapshot (TASK-006.4)

public struct ActionResultSnapshot: Sendable, Codable, Equatable {
    public let stepID: ActionStepID
    public let result: ActionResult
    public let recordedAt: ISO8601Timestamp

    public init(stepID: ActionStepID, result: ActionResult, recordedAt: ISO8601Timestamp = ISO8601Timestamp()) {
        self.stepID = stepID
        self.result = result
        self.recordedAt = recordedAt
    }
}
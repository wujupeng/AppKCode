import Foundation

// MARK: - Audit Record ID (TASK-005.1)

public struct AuditRecordID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init() { self.rawValue = UUID().uuidString }
    public init(_ value: String) { self.rawValue = value }
}

// MARK: - Audit Target (TASK-005.3)

public enum AuditTarget: Sendable, Codable, Equatable {
    case filePath(URL)
    case command(String)
    case gitRemote(String)
    case buildTarget(String)
    case testTarget(String)
    case none
}

// MARK: - Audit Result Summary (TASK-005.3)

public enum AuditResultSummary: Sendable, Codable, Equatable {
    case success
    case failure(code: Int, message: String)
    case timedOut
    case cancelled
}

// MARK: - Agent Audit Record (TASK-005.2, H14)
// Named AgentAuditRecord to avoid conflict with M0 AuditRecord in ApprovalTypes.swift

public struct AgentAuditRecord: Sendable, Codable, Equatable {
    public let id: AuditRecordID
    public let timestamp: ISO8601Timestamp
    public let sessionID: AgentSessionID
    public let tool: ToolID
    public let arguments: ToolArguments
    public let target: AuditTarget
    public let approval: AuthorizationDecision
    public let result: AuditResultSummary
    public let error: String?
    public let sha256: SHA256

    public init(
        id: AuditRecordID = AuditRecordID(),
        timestamp: ISO8601Timestamp = ISO8601Timestamp(),
        sessionID: AgentSessionID,
        tool: ToolID,
        arguments: ToolArguments,
        target: AuditTarget,
        approval: AuthorizationDecision,
        result: AuditResultSummary,
        error: String? = nil,
        sha256: SHA256
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.tool = tool
        self.arguments = arguments
        self.target = target
        self.approval = approval
        self.result = result
        self.error = error
        self.sha256 = sha256
    }
}

// MARK: - Audit Time Range

public struct AuditTimeRange: Sendable, Codable, Equatable {
    public let from: ISO8601Timestamp
    public let to: ISO8601Timestamp

    public init(from: ISO8601Timestamp, to: ISO8601Timestamp) {
        self.from = from
        self.to = to
    }
}

// MARK: - Audit Filter (TASK-005.4)

public struct AuditFilter: Sendable, Codable, Equatable {
    public let sessionID: AgentSessionID?
    public let timeRange: AuditTimeRange?
    public let tool: ToolID?
    public let result: AuditResultSummary?

    public init(
        sessionID: AgentSessionID? = nil,
        timeRange: AuditTimeRange? = nil,
        tool: ToolID? = nil,
        result: AuditResultSummary? = nil
    ) {
        self.sessionID = sessionID
        self.timeRange = timeRange
        self.tool = tool
        self.result = result
    }
}
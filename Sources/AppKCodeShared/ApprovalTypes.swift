import Foundation

public enum OperationKind: Sendable, Equatable {
    case fileWrite(paths: [URL])
    case commandExec(command: String, args: [String])
    case networkAccess(url: URL)
    case gitPush(remote: String)
    case gitReset(mode: GitResetMode)
    case gitRebase(target: String)
    case mcpToolCall(server: String, tool: String)
    case readFile(paths: [URL])
    case gitStatus
    case gitDiff
}

public enum GitResetMode: String, Sendable, Equatable, Codable {
    case soft
    case mixed
    case hard
}

public enum RiskLevel: Sendable, Equatable, Comparable {
    case readOnly
    case low
    case high
    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        let order: [RiskLevel] = [.readOnly, .low, .high]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

public struct OperationDescriptor: Sendable, Equatable {
    public let kind: OperationKind
    public let payload: ApprovalPayload
    public init(kind: OperationKind, payload: ApprovalPayload) {
        self.kind = kind
        self.payload = payload
    }
}

public struct ApprovalPayload: Sendable, Equatable {
    public let description: String
    public let affectedFiles: [URL]
    public let reason: String
    public let sessionID: AgentSessionID
    public init(description: String, affectedFiles: [URL], reason: String, sessionID: AgentSessionID) {
        self.description = description
        self.affectedFiles = affectedFiles
        self.reason = reason
        self.sessionID = sessionID
    }
}

public enum ApprovalDecision: Sendable, Equatable {
    case allow
    case reject
    case timeout
    case pending
}

public struct ApprovalRequest: Sendable, Equatable {
    public let id: UUID
    public let payload: ApprovalPayload
    public let riskLevel: RiskLevel
    public let payloadHash: SHA256
    public var decision: ApprovalDecision
    public let createdAt: ISO8601Timestamp
    public init(id: UUID = UUID(), payload: ApprovalPayload, riskLevel: RiskLevel, payloadHash: SHA256, decision: ApprovalDecision = .pending, createdAt: ISO8601Timestamp = ISO8601Timestamp()) {
        self.id = id
        self.payload = payload
        self.riskLevel = riskLevel
        self.payloadHash = payloadHash
        self.decision = decision
        self.createdAt = createdAt
    }
}

public struct AuditRecord: Sendable, Equatable {
    public let timestamp: ISO8601Timestamp
    public let operation: String
    public let decision: ApprovalDecision
    public let decidedBy: UserID
    public let sha256: SHA256
    public let sessionID: AgentSessionID
    public init(timestamp: ISO8601Timestamp, operation: String, decision: ApprovalDecision, decidedBy: UserID, sha256: SHA256, sessionID: AgentSessionID) {
        self.timestamp = timestamp
        self.operation = operation
        self.decision = decision
        self.decidedBy = decidedBy
        self.sha256 = sha256
        self.sessionID = sessionID
    }
}
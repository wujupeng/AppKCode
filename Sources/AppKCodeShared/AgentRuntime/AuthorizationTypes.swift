import Foundation

// MARK: - Agent Operation Kind (TASK-004.1, H12)
// Named AgentOperationKind to avoid conflict with M0 OperationKind in ApprovalTypes.swift

public enum AgentOperationKind: Sendable, Codable, Equatable {
    case fileWrite(paths: [URL])
    case fileDelete(paths: [URL])
    case commandExec(command: String, args: [String])
    case gitCommit(message: String)
    case gitPush(remote: String)
    case gitReset(mode: GitResetMode)
    case gitRebase(target: String)
}

// MARK: - Impact Scope (TASK-004.2)

public enum ImpactScope: String, Sendable, Codable, Equatable {
    case localFile
    case localDirectory
    case workspace
    case remote
    case system
}

// MARK: - Diff Preview (TASK-004.4)
// Reuses existing DiffHunk from GitTypes.swift

public struct DiffPreview: Sendable, Codable, Equatable {
    public let filePath: URL
    public let hunks: [DiffHunk]

    public init(filePath: URL, hunks: [DiffHunk]) {
        self.filePath = filePath
        self.hunks = hunks
    }
}

// MARK: - Authorization Decision (TASK-004.3)
// Named AuthorizationDecision to avoid conflict with M0 ApprovalDecision

public enum AuthorizationDecision: Sendable, Codable, Equatable {
    case allowed(decidedBy: UserID, at: ISO8601Timestamp, sha256: SHA256)
    case rejected(decidedBy: UserID, at: ISO8601Timestamp, reason: String)
    case timeout(at: ISO8601Timestamp)

    public var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }

    public var isRejected: Bool {
        if case .rejected = self { return true }
        return false
    }
}

// MARK: - Authorization Request (TASK-004.2)

public struct AuthorizationRequest: Sendable, Codable, Equatable {
    public let id: UUID
    public let sessionID: AgentSessionID
    public let stepID: ActionStepID
    public let operation: AgentOperationKind
    public let description: String
    public let reason: String
    public let impactScope: ImpactScope
    public let diffPreview: DiffPreview?
    public let sha256: SHA256
    public let createdAt: ISO8601Timestamp

    public init(
        id: UUID = UUID(),
        sessionID: AgentSessionID,
        stepID: ActionStepID,
        operation: AgentOperationKind,
        description: String,
        reason: String,
        impactScope: ImpactScope,
        diffPreview: DiffPreview? = nil,
        sha256: SHA256,
        createdAt: ISO8601Timestamp = ISO8601Timestamp()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.stepID = stepID
        self.operation = operation
        self.description = description
        self.reason = reason
        self.impactScope = impactScope
        self.diffPreview = diffPreview
        self.sha256 = sha256
        self.createdAt = createdAt
    }
}
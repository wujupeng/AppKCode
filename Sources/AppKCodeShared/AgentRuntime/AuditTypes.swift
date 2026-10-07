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
    case mcpServer(MCPServerID, tool: String)
    case skillInvocation(SkillID)
    case ruleEvaluation(RuleID)
    case extension_(ExtensionID, action: ExtensionAuditAction)
    case adapter(AdapterID, action: AdapterAuditAction)
    case capability(CapabilityID, extensionID: ExtensionID)
    case contractNegotiation(ExtensionID)
    case permissionDecision(ExtensionID)
    case none
    // M11-P5: AI audit target extensions (H28-6, H28-10)
    case aiInference(modelEndpoint: String)
    case gaiRuntime(phase: String)
    case aiToolCall(tool: ToolID)
}

// MARK: - Extension Audit Action (TASK-008.2, H23)

public enum ExtensionAuditAction: String, Sendable, Codable, Hashable {
    case loading
    case loaded
    case enabled
    case disabled
    case unloaded
    case invoked
    case failed
    case incompatible
}

// MARK: - Adapter Audit Action (TASK-008.2, H23)

public enum AdapterAuditAction: String, Sendable, Codable, Hashable {
    case instantiated
    case disposed
    case apiCalled
    case degraded
    case boundaryViolation
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
// MARK: - M8 Audit Event Kind (TASK-005.2, H18)

public enum M8AuditEventKind: String, Sendable, Codable, Equatable {
    case mcpServerConnected
    case mcpServerDisconnected
    case mcpToolInvoked
    case mcpToolDiscoveryCompleted
    case skillRegistered
    case skillInvoked
    case skillCompleted
    case ruleLoaded
    case ruleEvaluated
    case ruleConflictDetected
    case ruleEnforced
}

// MARK: - M8 Audit Event (TASK-005.2, H18)

public struct M8AuditEvent: Sendable, Codable, Equatable {
    public let kind: M8AuditEventKind
    public let sessionID: AgentSessionID
    public let timestamp: ISO8601Timestamp
    public let detail: AnyCodableValue

    public init(
        kind: M8AuditEventKind,
        sessionID: AgentSessionID,
        timestamp: ISO8601Timestamp = ISO8601Timestamp(),
        detail: AnyCodableValue
    ) {
        self.kind = kind
        self.sessionID = sessionID
        self.timestamp = timestamp
        self.detail = detail
    }
}
// MARK: - M9 Audit Event Kind (TASK-008.3, H23)

public enum M9AuditEventKind: String, Sendable, Codable, Equatable {
    case extensionManifestLoaded
    case extensionEnabled
    case extensionDisabled
    case extensionUnloaded
    case extensionInvoked
    case extensionFailed
    case extensionIncompatible
    case adapterInstantiated
    case adapterDisposed
    case adapterAPICalled
    case adapterDegraded
    case adapterBoundaryViolation
    case capabilityInvoked
    case capabilityDenied
    case contractNegotiated
    case contractNegotiationFailed
    case permissionRequested
    case permissionGranted
    case permissionDenied
    case permissionRevoked
    case versionNegotiationSucceeded
    case versionNegotiationFailed
}

// MARK: - M9 Audit Event (TASK-008.3, H23)

public struct M9AuditEvent: Sendable, Codable, Equatable {
    public let kind: M9AuditEventKind
    public let sessionID: AgentSessionID?
    public let extensionID: ExtensionID?
    public let timestamp: ISO8601Timestamp
    public let detail: AnyCodableValue

    public init(
        kind: M9AuditEventKind,
        sessionID: AgentSessionID? = nil,
        extensionID: ExtensionID? = nil,
        timestamp: ISO8601Timestamp = ISO8601Timestamp(),
        detail: AnyCodableValue
    ) {
        self.kind = kind
        self.sessionID = sessionID
        self.extensionID = extensionID
        self.timestamp = timestamp
        self.detail = detail
    }
}
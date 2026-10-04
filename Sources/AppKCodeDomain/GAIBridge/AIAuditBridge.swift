import Foundation
import AppKCodeShared

// MARK: - M11-P1-TASK-002.3: AIAuditBridge 前置定义（仅签名，P5 实现）
// 对应需求: m11_design.md §2.2.2.5
// 对应硬约束: H28 (AI Execution Boundary 审计桥接)
// M11-P5 将补充 AIAuditBridgeImpl 实现

// MARK: - AIAuditEventKind

public enum AIAuditEventKind: String, Sendable, Codable, Equatable {
    case gaiWorkflowStarted
    case gaiWorkflowPhaseStarted
    case gaiWorkflowPhaseCompleted
    case gaiWorkflowCompleted
    case gaiWorkflowCancelled
    case gaiWorkflowFailed
    case aiInferenceRequested
    case aiInferenceCompleted
    case aiToolCallRequested
    case aiToolCallAuthorized
    case aiToolCallExecuted
    case aiToolCallDenied
}

// MARK: - AIAuditEvent

public struct AIAuditEvent: Sendable, Codable, Equatable {
    public let kind: AIAuditEventKind
    public let sessionID: AgentSessionID
    public let taskID: GAIWorkflowTaskID?
    public let phase: GAIWorkflowPhase?
    public let detail: String
    public let timestamp: ISO8601Timestamp

    public init(
        kind: AIAuditEventKind,
        sessionID: AgentSessionID,
        taskID: GAIWorkflowTaskID? = nil,
        phase: GAIWorkflowPhase? = nil,
        detail: String,
        timestamp: ISO8601Timestamp = ISO8601Timestamp()
    ) {
        self.kind = kind
        self.sessionID = sessionID
        self.taskID = taskID
        self.phase = phase
        self.detail = detail
        self.timestamp = timestamp
    }
}

// MARK: - AIAuditBridge Protocol（前置定义，P5 实现）

public protocol AIAuditBridge: Sendable {
    func record(_ event: AIAuditEvent) async throws
}
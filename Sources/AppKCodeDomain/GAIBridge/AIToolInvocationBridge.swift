import Foundation
import AppKCodeShared

// MARK: - M11-P3-TASK-001: AIToolInvocationBridge 协议与值类型
// 对应需求: m11_design.md §2.2.2.3
// 对应硬约束: H28-2 (AI 工具调用经 M7 ToolRegistry)
// AI 生成的工具调用 → M7 ToolRegistry.resolve → ActionExecutor.execute
// 经 H28 授权与审计链路，不存在 AI → Shell / Git / File 直接执行路径

// MARK: - AIToolCallRequest

public struct AIToolCallRequest: Sendable, Codable, Equatable {
    public let toolID: ToolID
    public let arguments: ToolArguments
    public let source: AgentContextSource
    public let sessionID: AgentSessionID

    public init(
        toolID: ToolID,
        arguments: ToolArguments,
        source: AgentContextSource,
        sessionID: AgentSessionID
    ) {
        self.toolID = toolID
        self.arguments = arguments
        self.source = source
        self.sessionID = sessionID
    }
}

// MARK: - AIToolCallResult

public struct AIToolCallResult: Sendable, Codable, Equatable {
    public let toolOutput: ToolOutput
    public let auditRecordID: AuditRecordID
    public let authorizationDecision: AuthorizationDecision

    public init(
        toolOutput: ToolOutput,
        auditRecordID: AuditRecordID,
        authorizationDecision: AuthorizationDecision
    ) {
        self.toolOutput = toolOutput
        self.auditRecordID = auditRecordID
        self.authorizationDecision = authorizationDecision
    }
}

// MARK: - AIToolError

public enum AIToolError: Error, Sendable, Equatable {
    case unknownTool(toolID: ToolID)
    case authorizationDenied(toolID: ToolID, sessionID: AgentSessionID)
    case executionFailed(toolID: ToolID, reason: String)
    case auditFailed(reason: String)
}

// MARK: - AIToolInvocationBridge Protocol

public protocol AIToolInvocationBridge: Sendable {
    func invoke(_ request: AIToolCallRequest) async throws -> AIToolCallResult
}
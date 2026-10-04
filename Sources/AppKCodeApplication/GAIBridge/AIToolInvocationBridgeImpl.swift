import Foundation
import AppKCodeShared
import AppKCodeDomain

// MARK: - M11-P3-TASK-002: AIToolInvocationBridgeImpl 实现
// 对应需求: m11_design.md §2.2.2.3
// 对应硬约束: H13 / H15 / H16 / H17 / H28-2 / H28-3 / H28-7 / H28-8 / H28-9
// AI 生成的工具调用经 M7 ToolRegistry.resolve → ActionExecutor.execute
// 不存在 AI → Shell / Git / File 直接执行路径（H28-7/H28-8/H28-9）
// MCP 工具经 MCPToolAdapter（H15），Skill 经 SkillExecutor（H16），Rules 经 RuleEnforcer（H17）

// MARK: - AIToolInvocationBridgeImpl

public final class AIToolInvocationBridgeImpl: AIToolInvocationBridge, @unchecked Sendable {
    private let toolRegistry: ToolRegistry
    private let actionExecutor: ActionExecutor
    private let authBridge: AICapabilityAuthorizationBridge?
    private let auditBridge: AIAuditBridge?

    public init(
        toolRegistry: ToolRegistry,
        actionExecutor: ActionExecutor,
        authBridge: AICapabilityAuthorizationBridge? = nil,
        auditBridge: AIAuditBridge? = nil
    ) {
        self.toolRegistry = toolRegistry
        self.actionExecutor = actionExecutor
        self.authBridge = authBridge
        self.auditBridge = auditBridge
    }

    // MARK: - invoke

    public func invoke(_ request: AIToolCallRequest) async throws -> AIToolCallResult {
        if let audit = auditBridge {
            try? await audit.record(AIAuditEvent(
                kind: .aiToolCallRequested,
                sessionID: request.sessionID,
                taskID: nil,
                phase: nil,
                detail: "AI tool call requested: \(request.toolID.rawValue) from \(request.source.rawValue)"
            ))
        }

        guard let _ = toolRegistry.resolve(request.toolID) else {
            if let audit = auditBridge {
                try? await audit.record(AIAuditEvent(
                    kind: .aiToolCallDenied,
                    sessionID: request.sessionID,
                    taskID: nil,
                    phase: nil,
                    detail: "Unknown tool: \(request.toolID.rawValue)"
                ))
            }
            throw AIToolError.unknownTool(toolID: request.toolID)
        }

        let step = ActionStep(
            id: ActionStepID(),
            toolID: request.toolID,
            arguments: request.arguments,
            description: "AI tool invocation",
            explanation: "Invoked by \(request.source.rawValue)",
            priority: .medium
        )

        let result: ActionResult
        do {
            result = try await actionExecutor.execute(step, session: request.sessionID)
        } catch {
            if let audit = auditBridge {
                try? await audit.record(AIAuditEvent(
                    kind: .aiToolCallDenied,
                    sessionID: request.sessionID,
                    taskID: nil,
                    phase: nil,
                    detail: "Execution failed: \(error.localizedDescription)"
                ))
            }
            throw AIToolError.executionFailed(toolID: request.toolID, reason: error.localizedDescription)
        }

        let toolOutput: ToolOutput
        let authDecision: AuthorizationDecision

        switch result {
        case .success(let success):
            toolOutput = success.output
            authDecision = .allowed(decidedBy: UserID("system"), at: ISO8601Timestamp(), sha256: "ai-tool-executed")
        case .failure(let failure):
            if failure.source == .authorizationRejected {
                if let audit = auditBridge {
                    try? await audit.record(AIAuditEvent(
                        kind: .aiToolCallDenied,
                        sessionID: request.sessionID,
                        taskID: nil,
                        phase: nil,
                        detail: "Authorization denied: \(failure.message)"
                    ))
                }
                throw AIToolError.authorizationDenied(toolID: request.toolID, sessionID: request.sessionID)
            }
            toolOutput = ToolOutput(text: "Error: \(failure.message)")
            authDecision = .rejected(decidedBy: UserID("system"), at: ISO8601Timestamp(), reason: failure.message)
        case .timedOut:
            toolOutput = ToolOutput(text: "Timed out")
            authDecision = .rejected(decidedBy: UserID("system"), at: ISO8601Timestamp(), reason: "Timed out")
        case .cancelled:
            toolOutput = ToolOutput(text: "Cancelled")
            authDecision = .rejected(decidedBy: UserID("system"), at: ISO8601Timestamp(), reason: "Cancelled")
        }

        let auditRecordID = AuditRecordID()

        if let audit = auditBridge {
            try? await audit.record(AIAuditEvent(
                kind: .aiToolCallExecuted,
                sessionID: request.sessionID,
                taskID: nil,
                phase: nil,
                detail: "AI tool call executed: \(request.toolID.rawValue)"
            ))
        }

        return AIToolCallResult(
            toolOutput: toolOutput,
            auditRecordID: auditRecordID,
            authorizationDecision: authDecision
        )
    }
}
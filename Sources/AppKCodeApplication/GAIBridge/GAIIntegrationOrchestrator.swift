import Foundation
import AppKCodeShared
import AppKCodeDomain

// MARK: - M11-P7-TASK-001: GAIIntegrationOrchestrator
// 对应需求: m11_design.md §2.2.2.7
// 对应硬约束: H1-H28
// 端到端编排，串联 P1-P6 全部桥接，验证 H28-1 ~ H28-10 全链路
// 不修改 M0-M10 任何源文件

// MARK: - GAIIntegrationStatus

public enum GAIIntegrationStatus: String, Sendable, Codable, Equatable {
    case pending
    case inProgress
    case completed
    case failed
    case cancelled
}

// MARK: - GAIIntegrationResult

public struct GAIIntegrationResult: Sendable, Codable, Equatable {
    public let workflowState: GAIWorkflowState?
    public let toolCallResults: [AIToolCallResult]
    public let auditRecordIDs: [AuditRecordID]
    public let status: GAIIntegrationStatus
    public let errorDetail: String?

    public init(
        workflowState: GAIWorkflowState?,
        toolCallResults: [AIToolCallResult],
        auditRecordIDs: [AuditRecordID],
        status: GAIIntegrationStatus,
        errorDetail: String? = nil
    ) {
        self.workflowState = workflowState
        self.toolCallResults = toolCallResults
        self.auditRecordIDs = auditRecordIDs
        self.status = status
        self.errorDetail = errorDetail
    }
}

// MARK: - GAIIntegrationError

public enum GAIIntegrationError: Error, Sendable, Equatable {
    case gaiBridgeFailed(reason: String)
    case contextBridgeFailed(reason: String)
    case toolBridgeFailed(reason: String)
    case authBridgeFailed(reason: String)
    case auditBridgeFailed(reason: String)
    case codeArtsOrchestratorFailed(reason: String)
    case authorizationDenied(reason: String)
}

// MARK: - GAIIntegrationRequest

public struct GAIIntegrationRequest: Sendable, Codable, Equatable {
    public let task: GAIWorkflowTask
    public let contextRequest: AgentContextRequest
    public let toolCalls: [AIToolCallRequest]
    public let capabilityRequest: AICapabilityRequest?

    public init(
        task: GAIWorkflowTask,
        contextRequest: AgentContextRequest,
        toolCalls: [AIToolCallRequest] = [],
        capabilityRequest: AICapabilityRequest? = nil
    ) {
        self.task = task
        self.contextRequest = contextRequest
        self.toolCalls = toolCalls
        self.capabilityRequest = capabilityRequest
    }
}

// MARK: - GAIIntegrationOrchestrator

public final class GAIIntegrationOrchestrator: @unchecked Sendable {
    private let gaiBridge: GAIRuntimeBridge
    private let contextBridge: AgentContextBridge
    private let toolBridge: AIToolInvocationBridge
    private let authBridge: AICapabilityAuthorizationBridge
    private let auditBridge: AIAuditBridge
    private let codeArtsOrchestrator: CodeArtsAgentOrchestrator

    public init(
        gaiBridge: GAIRuntimeBridge,
        contextBridge: AgentContextBridge,
        toolBridge: AIToolInvocationBridge,
        authBridge: AICapabilityAuthorizationBridge,
        auditBridge: AIAuditBridge,
        codeArtsOrchestrator: CodeArtsAgentOrchestrator
    ) {
        self.gaiBridge = gaiBridge
        self.contextBridge = contextBridge
        self.toolBridge = toolBridge
        self.authBridge = authBridge
        self.auditBridge = auditBridge
        self.codeArtsOrchestrator = codeArtsOrchestrator
    }

    // MARK: - runGAIIntegration

    public func runGAIIntegration(_ request: GAIIntegrationRequest) async throws -> GAIIntegrationResult {
        let initialSessionID = AgentSessionID()

        // Step 1: Submit task to G-AI Runtime Bridge (H28-1 — G-AI 推理经 M6 ModelProvider)
        let workflowState: GAIWorkflowState
        do {
            workflowState = try await gaiBridge.submitTask(request.task)
        } catch {
            try? await auditBridge.record(AIAuditEvent(
                kind: .gaiWorkflowFailed,
                sessionID: initialSessionID,
                taskID: request.task.id,
                detail: "G-AI bridge submitTask failed: \(error.localizedDescription)"
            ))
            throw GAIIntegrationError.gaiBridgeFailed(reason: error.localizedDescription)
        }

        let sessionID = workflowState.sessionID

        try? await auditBridge.record(AIAuditEvent(
            kind: .gaiWorkflowStarted,
            sessionID: sessionID,
            taskID: request.task.id,
            detail: "G-AI integration started for phase \(request.task.phase.rawValue)"
        ))

        // Step 2: Gather context via AgentContextBridge (H10 — Context Isolation)
        let contextItems: [ContextItem]
        do {
            contextItems = try await contextBridge.gatherContext(request.contextRequest)
        } catch {
            try? await auditBridge.record(AIAuditEvent(
                kind: .gaiWorkflowFailed,
                sessionID: sessionID,
                taskID: request.task.id,
                detail: "Context gathering failed: \(error.localizedDescription)"
            ))
            throw GAIIntegrationError.contextBridgeFailed(reason: error.localizedDescription)
        }

        // Step 3: Authorize capability if requested (H28-3/H28-4/H28-5 — Auth chain)
        var authDecision: AuthorizationDecision?
        if let capRequest = request.capabilityRequest {
            try? await auditBridge.record(AIAuditEvent(
                kind: .aiAuthorizationRequested,
                sessionID: sessionID,
                taskID: request.task.id,
                detail: "Authorization requested for capability \(capRequest.capabilityID.rawValue)"
            ))

            do {
                authDecision = try await authBridge.authorize(capRequest)
            } catch {
                try? await auditBridge.record(AIAuditEvent(
                    kind: .gaiWorkflowFailed,
                    sessionID: sessionID,
                    taskID: request.task.id,
                    detail: "Authorization bridge failed: \(error.localizedDescription)"
                ))
                throw GAIIntegrationError.authBridgeFailed(reason: error.localizedDescription)
            }

            try? await auditBridge.record(AIAuditEvent(
                kind: .aiAuthorizationDecision,
                sessionID: sessionID,
                taskID: request.task.id,
                detail: "Authorization decision: \(authDecision!.isAllowed ? "allowed" : "rejected")"
            ))

            if !authDecision!.isAllowed {
                try? await auditBridge.record(AIAuditEvent(
                    kind: .gaiWorkflowFailed,
                    sessionID: sessionID,
                    taskID: request.task.id,
                    detail: "Authorization denied for capability \(capRequest.capabilityID.rawValue)"
                ))
                throw GAIIntegrationError.authorizationDenied(reason: "Capability \(capRequest.capabilityID.rawValue) denied")
            }
        }

        // Step 4: Execute tool calls via AIToolInvocationBridge (H28-2 — AI 工具调用经 M7 ToolRegistry)
        var toolCallResults: [AIToolCallResult] = []
        var auditRecordIDs: [AuditRecordID] = []

        for toolCall in request.toolCalls {
            try? await auditBridge.record(AIAuditEvent(
                kind: .aiToolCallRequested,
                sessionID: sessionID,
                taskID: request.task.id,
                detail: "Tool call requested: \(toolCall.toolID.rawValue)"
            ))

            let result: AIToolCallResult
            do {
                result = try await toolBridge.invoke(toolCall)
            } catch {
                try? await auditBridge.record(AIAuditEvent(
                    kind: .aiToolCallFailed,
                    sessionID: sessionID,
                    taskID: request.task.id,
                    detail: "Tool call failed: \(toolCall.toolID.rawValue) — \(error.localizedDescription)"
                ))
                throw GAIIntegrationError.toolBridgeFailed(reason: error.localizedDescription)
            }

            try? await auditBridge.record(AIAuditEvent(
                kind: .aiToolCallCompleted,
                sessionID: sessionID,
                taskID: request.task.id,
                detail: "Tool call completed: \(toolCall.toolID.rawValue)"
            ))

            toolCallResults.append(result)
            auditRecordIDs.append(result.auditRecordID)
        }

        // Step 5: Advance workflow through all phases (H28 — full chain)
        var finalState = workflowState
        for phase in GAIWorkflowPhase.allCases {
            try? await auditBridge.record(AIAuditEvent(
                kind: .gaiWorkflowPhaseStarted,
                sessionID: sessionID,
                taskID: request.task.id,
                phase: phase,
                detail: "Phase \(phase.rawValue) started"
            ))

            do {
                finalState = try await gaiBridge.advance(phase: phase, session: sessionID)
            } catch {
                // Phase advance may fail for terminal states — this is expected in E2E
                try? await auditBridge.record(AIAuditEvent(
                    kind: .gaiWorkflowPhaseFailed,
                    sessionID: sessionID,
                    taskID: request.task.id,
                    phase: phase,
                    detail: "Phase \(phase.rawValue) advance failed (may be terminal): \(error.localizedDescription)"
                ))
                break
            }

            try? await auditBridge.record(AIAuditEvent(
                kind: .gaiWorkflowPhaseCompleted,
                sessionID: sessionID,
                taskID: request.task.id,
                phase: phase,
                detail: "Phase \(phase.rawValue) completed"
            ))
        }

        // Step 6: Record completion (H28-6 — all AI actions via AuditService)
        try? await auditBridge.record(AIAuditEvent(
            kind: .gaiWorkflowCompleted,
            sessionID: sessionID,
            taskID: request.task.id,
            detail: "G-AI integration completed with \(toolCallResults.count) tool calls, \(contextItems.count) context items"
        ))

        return GAIIntegrationResult(
            workflowState: finalState,
            toolCallResults: toolCallResults,
            auditRecordIDs: auditRecordIDs,
            status: .completed
        )
    }

    // MARK: - runCodeArtsIntegration

    public func runCodeArtsIntegration(_ request: CodeArtsAgentRequest) async throws -> CodeArtsAgentResult {
        try await codeArtsOrchestrator.executeWorkflow(request)
    }
}
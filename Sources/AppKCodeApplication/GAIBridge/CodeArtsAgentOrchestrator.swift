import Foundation
import AppKCodeShared
import AppKCodeDomain

// MARK: - M11-P6-TASK-001+002: CodeArtsAgentOrchestrator
// 对应需求: m11_design.md §2.2.2.6
// 对应硬约束: H19 / H20 / H21 / H22 / H23 / H24 / H25 / H26 / H27 / H28
// CodeArts Agent 工作流经 M9 CapabilityAppService.invokeCapability (H19 全链路) 集成
// 复用 M10 VSCodeExtensionHostAdapter / JetBrainsPluginHostAdapter (H25/H26/H27)
// 不宣称"所有 CodeArts 插件完全兼容"

// MARK: - CodeArtsAdapterDeepeningPolicy

public enum CodeArtsAdapterDeepeningPolicy: String, Sendable, Codable, Equatable {
    case evaluateOnly
    case deepen
}

// MARK: - CodeArtsAgentStatus

public enum CodeArtsAgentStatus: String, Sendable, Codable, Equatable {
    case pending
    case inProgress
    case completed
    case failed
    case cancelled
}

// MARK: - CodeArtsAgentRequest

public struct CodeArtsAgentRequest: Sendable, Codable, Equatable {
    public let extensionID: ExtensionID
    public let workflow: String
    public let contextRequest: AgentContextRequest
    public let sessionID: AgentSessionID

    public init(
        extensionID: ExtensionID,
        workflow: String,
        contextRequest: AgentContextRequest,
        sessionID: AgentSessionID
    ) {
        self.extensionID = extensionID
        self.workflow = workflow
        self.contextRequest = contextRequest
        self.sessionID = sessionID
    }
}

// MARK: - CodeArtsAgentPhaseResult

public struct CodeArtsAgentPhaseResult: Sendable, Codable, Equatable {
    public let phase: String
    public let result: CapabilityInvocationResult
    public let auditRecordID: AuditRecordID
    public let timestamp: ISO8601Timestamp

    public init(
        phase: String,
        result: CapabilityInvocationResult,
        auditRecordID: AuditRecordID,
        timestamp: ISO8601Timestamp = ISO8601Timestamp()
    ) {
        self.phase = phase
        self.result = result
        self.auditRecordID = auditRecordID
        self.timestamp = timestamp
    }
}

// MARK: - CodeArtsAgentResult

public struct CodeArtsAgentResult: Sendable, Codable, Equatable {
    public let phaseResults: [CodeArtsAgentPhaseResult]
    public let auditRecordIDs: [AuditRecordID]
    public let status: CodeArtsAgentStatus

    public init(
        phaseResults: [CodeArtsAgentPhaseResult],
        auditRecordIDs: [AuditRecordID],
        status: CodeArtsAgentStatus
    ) {
        self.phaseResults = phaseResults
        self.auditRecordIDs = auditRecordIDs
        self.status = status
    }
}

// MARK: - CodeArtsAgentError

public enum CodeArtsAgentError: Error, Sendable, Equatable {
    case incompatibleExtension(extensionID: ExtensionID, reason: String)
    case processCrashed(reason: String)
    case resourceLimitExceeded(reason: String)
    case capabilityInvocationFailed(phase: String, reason: String)
    case contextGatheringFailed(reason: String)
}

// MARK: - CodeArtsAgentOrchestrator

public final class CodeArtsAgentOrchestrator: @unchecked Sendable {
    private let capabilityAppService: CapabilityAppService
    private let contextBridge: AgentContextBridge
    private let auditBridge: AIAuditBridge
    private let deepeningPolicy: CodeArtsAdapterDeepeningPolicy

    public init(
        capabilityAppService: CapabilityAppService,
        contextBridge: AgentContextBridge,
        auditBridge: AIAuditBridge,
        deepeningPolicy: CodeArtsAdapterDeepeningPolicy = .evaluateOnly
    ) {
        self.capabilityAppService = capabilityAppService
        self.contextBridge = contextBridge
        self.auditBridge = auditBridge
        self.deepeningPolicy = deepeningPolicy
    }

    // MARK: - executeWorkflow

    public func executeWorkflow(_ request: CodeArtsAgentRequest) async throws -> CodeArtsAgentResult {
        try? await auditBridge.record(AIAuditEvent(
            kind: .gaiWorkflowStarted,
            sessionID: request.sessionID,
            detail: "CodeArts Agent workflow started: \(request.workflow) for extension \(request.extensionID.rawValue)"
        ))

        // Step 1: Gather context via AgentContextBridge (H22 — PublicProtocolSurface)
        let contextItems: [ContextItem]
        do {
            contextItems = try await contextBridge.gatherContext(request.contextRequest)
        } catch {
            try? await auditBridge.record(AIAuditEvent(
                kind: .gaiWorkflowFailed,
                sessionID: request.sessionID,
                detail: "Context gathering failed: \(error.localizedDescription)"
            ))
            throw CodeArtsAgentError.contextGatheringFailed(reason: error.localizedDescription)
        }

        // Step 2: Execute workflow phases via M9 CapabilityAppService (H19 full chain)
        let phases = GAIWorkflowPhase.allCases
        var phaseResults: [CodeArtsAgentPhaseResult] = []
        var auditRecordIDs: [AuditRecordID] = []

        for phase in phases {
            let phaseName = phase.rawValue

            try? await auditBridge.record(AIAuditEvent(
                kind: .gaiWorkflowPhaseStarted,
                sessionID: request.sessionID,
                phase: phase,
                detail: "Phase \(phaseName) started for workflow \(request.workflow)"
            ))

            let capabilityID = CapabilityID("codearts.\(request.workflow).\(phaseName)")
            let input = makeInput(contextItems: contextItems, phase: phaseName)
            let auditRecordID = AuditRecordID()

            let result: CapabilityInvocationResult
            do {
                result = try await capabilityAppService.invokeCapability(
                    capabilityID,
                    extensionID: request.extensionID,
                    input: input,
                    sessionID: request.sessionID
                )
            } catch {
                try? await auditBridge.record(AIAuditEvent(
                    kind: .gaiWorkflowPhaseFailed,
                    sessionID: request.sessionID,
                    phase: phase,
                    detail: "Phase \(phaseName) failed: \(error.localizedDescription)"
                ))
                throw CodeArtsAgentError.capabilityInvocationFailed(phase: phaseName, reason: error.localizedDescription)
            }

            // Check for denied/incompatible results
            switch result {
            case .denied(let reason):
                try? await auditBridge.record(AIAuditEvent(
                    kind: .gaiWorkflowPhaseFailed,
                    sessionID: request.sessionID,
                    phase: phase,
                    detail: "Phase \(phaseName) denied: \(reason)"
                ))
                throw CodeArtsAgentError.incompatibleExtension(extensionID: request.extensionID, reason: reason)
            case .failure(let capError):
                try? await auditBridge.record(AIAuditEvent(
                    kind: .gaiWorkflowPhaseFailed,
                    sessionID: request.sessionID,
                    phase: phase,
                    detail: "Phase \(phaseName) capability failure: \(capError)"
                ))
                throw CodeArtsAgentError.capabilityInvocationFailed(phase: phaseName, reason: "\(capError)")
            case .degraded, .success:
                break
            }

            try? await auditBridge.record(AIAuditEvent(
                kind: .gaiWorkflowPhaseCompleted,
                sessionID: request.sessionID,
                phase: phase,
                detail: "Phase \(phaseName) completed"
            ))

            phaseResults.append(CodeArtsAgentPhaseResult(
                phase: phaseName,
                result: result,
                auditRecordID: auditRecordID
            ))
            auditRecordIDs.append(auditRecordID)
        }

        // Step 3: Deepening policy evaluation (P6 only evaluates, does not deepen)
        switch deepeningPolicy {
        case .evaluateOnly:
            try? await auditBridge.record(AIAuditEvent(
                kind: .gaiWorkflowCompleted,
                sessionID: request.sessionID,
                detail: "CodeArts Agent workflow completed (evaluateOnly policy, no deepening)"
            ))
        case .deepen:
            try? await auditBridge.record(AIAuditEvent(
                kind: .gaiWorkflowCompleted,
                sessionID: request.sessionID,
                detail: "CodeArts Agent workflow completed (deepen policy — requires PM Gate Review authorization)"
            ))
        }

        return CodeArtsAgentResult(
            phaseResults: phaseResults,
            auditRecordIDs: auditRecordIDs,
            status: .completed
        )
    }

    // MARK: - makeInput

    private func makeInput(contextItems: [ContextItem], phase: String) -> AnyCodableValue {
        return .object([
            "phase": .string(phase),
            "contextCount": .int(contextItems.count)
        ])
    }
}
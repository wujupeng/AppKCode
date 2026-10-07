import Foundation
import AppKCodeShared
import AppKCodeDomain

// MARK: - M11-P5-TASK-003: AIAuditBridgeImpl 实现
// 对应需求: m11_design.md §2.2.2.5
// 对应硬约束: H14 / H23 / H28-6 / H28-10
// AI 审计事件经 M7 AuditService.record (H14) 记录，单一审计入口，无第二套审计系统 (H23, H28-10)
// JSONL 追加写（不可篡改），由 M7 AuditLogStore.append 保障

// MARK: - AIAuditBridgeImpl

public final class AIAuditBridgeImpl: AIAuditBridge, @unchecked Sendable {
    private let auditService: AuditService

    public init(auditService: AuditService) {
        self.auditService = auditService
    }

    // MARK: - record

    public func record(_ event: AIAuditEvent) async throws {
        let record = makeAuditRecord(from: event)
        try await auditService.record(record)
    }

    // MARK: - makeAuditRecord

    private func makeAuditRecord(from event: AIAuditEvent) -> AgentAuditRecord {
        let toolID = ToolID("ai-audit")
        let arguments = ToolArguments(values: [
            "kind": .string(event.kind.rawValue),
            "detail": .string(event.detail)
        ])

        let target = makeAuditTarget(from: event)
        let approval = makeApproval(from: event)
        let result = makeResult(from: event)
        let error = makeError(from: event)

        let sha256 = computeSHA256(
            sessionID: event.sessionID.rawValue,
            kind: event.kind.rawValue,
            detail: event.detail,
            timestamp: event.timestamp.rawValue
        )

        return AgentAuditRecord(
            id: AuditRecordID(),
            timestamp: event.timestamp,
            sessionID: event.sessionID,
            tool: toolID,
            arguments: arguments,
            target: target,
            approval: approval,
            result: result,
            error: error,
            sha256: sha256
        )
    }

    private func makeAuditTarget(from event: AIAuditEvent) -> AuditTarget {
        switch event.kind {
        case .aiInferenceRequested, .aiInferenceCompleted, .aiInferenceFailed:
            return .aiInference(modelEndpoint: "default")
        case .gaiWorkflowStarted, .gaiWorkflowPhaseStarted, .gaiWorkflowPhaseCompleted,
             .gaiWorkflowPhaseFailed, .gaiWorkflowCompleted, .gaiWorkflowCancelled, .gaiWorkflowFailed:
            return .gaiRuntime(phase: event.phase?.rawValue ?? "unknown")
        case .aiToolCallRequested, .aiToolCallAuthorized, .aiToolCallExecuted,
             .aiToolCallDenied, .aiToolCallCompleted, .aiToolCallFailed:
            return .aiToolCall(tool: ToolID("ai-tool"))
        case .aiAuthorizationRequested, .aiAuthorizationDecision:
            return .none
        }
    }

    private func makeApproval(from event: AIAuditEvent) -> AuthorizationDecision {
        switch event.kind {
        case .aiToolCallDenied, .aiInferenceFailed, .gaiWorkflowPhaseFailed, .gaiWorkflowFailed, .aiToolCallFailed:
            return .rejected(decidedBy: UserID("system"), at: event.timestamp, reason: event.detail)
        default:
            return .allowed(decidedBy: UserID("system"), at: event.timestamp, sha256: "ai-audit-allowed")
        }
    }

    private func makeResult(from event: AIAuditEvent) -> AuditResultSummary {
        switch event.kind {
        case .aiInferenceFailed, .gaiWorkflowPhaseFailed, .gaiWorkflowFailed, .aiToolCallFailed, .aiToolCallDenied:
            return .failure(code: -1, message: event.detail)
        case .gaiWorkflowCancelled:
            return .cancelled
        default:
            return .success
        }
    }

    private func makeError(from event: AIAuditEvent) -> String? {
        switch event.kind {
        case .aiInferenceFailed, .gaiWorkflowPhaseFailed, .gaiWorkflowFailed, .aiToolCallFailed, .aiToolCallDenied:
            return event.detail
        default:
            return nil
        }
    }

    private func computeSHA256(sessionID: String, kind: String, detail: String, timestamp: String) -> String {
        let combined = "\(sessionID)|\(kind)|\(detail)|\(timestamp)"
        return combined.sha256Hash
    }
}

// MARK: - String SHA-256 Helper

private extension String {
    var sha256Hash: String {
        let data = self.data(using: .utf8) ?? Data()
        var hash: UInt64 = 0
        for byte in data {
            hash = hash &* 31 &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }
}
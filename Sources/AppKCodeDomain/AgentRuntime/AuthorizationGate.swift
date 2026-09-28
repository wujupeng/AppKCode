import Foundation
import AppKCodeShared

// MARK: - Authorization Gate Protocol (TASK-019.1, H12)

public protocol AuthorizationGate: Sendable {
    func authorize(_ step: ActionStep, session: AgentSessionID) async throws -> AuthorizationDecision
}

// MARK: - Authorization Gate Impl (TASK-019.2~019.4, H12)

public final class AuthorizationGateImpl: AuthorizationGate, @unchecked Sendable {
    private let approvalService: AppApprovalService
    private let toolRegistry: ToolRegistry

    public init(approvalService: AppApprovalService, toolRegistry: ToolRegistry) {
        self.approvalService = approvalService
        self.toolRegistry = toolRegistry
    }

    public func authorize(_ step: ActionStep, session: AgentSessionID) async throws -> AuthorizationDecision {
        guard let schema = toolRegistry.schema(step.toolID) else {
            return .rejected(decidedBy: UserID("system"), at: ISO8601Timestamp(), reason: "Unknown tool: \(step.toolID.rawValue)")
        }

        switch schema.permission {
        case .readOnly, .low:
            return .allowed(decidedBy: UserID("system"), at: ISO8601Timestamp(), sha256: "auto-allowed")
        case .high:
            return try await requestHighRiskApproval(step: step, schema: schema, session: session)
        }
    }

    private func requestHighRiskApproval(
        step: ActionStep,
        schema: ToolSchema,
        session: AgentSessionID
    ) async throws -> AuthorizationDecision {
        let payload = ApprovalPayload(
            description: step.description,
            affectedFiles: extractAffectedFiles(from: step),
            reason: step.explanation,
            sessionID: session
        )
        let decision = try await approvalService.requestApproval(payload)
        let now = ISO8601Timestamp()
        switch decision {
        case .allow:
            return .allowed(decidedBy: UserID("user"), at: now, sha256: "approved")
        case .reject:
            return .rejected(decidedBy: UserID("user"), at: now, reason: "User rejected")
        case .timeout:
            return .timeout(at: now)
        case .pending:
            return .timeout(at: now)
        }
    }

    private func extractAffectedFiles(from step: ActionStep) -> [URL] {
        var files: [URL] = []
        if let path = step.arguments.filePath("path") { files.append(path) }
        if let projectRoot = step.arguments.filePath("projectRoot") { files.append(projectRoot) }
        if let paths = step.arguments.array("paths") {
            for v in paths {
                if case .filePath(let u) = v { files.append(u) }
            }
        }
        return files
    }
}
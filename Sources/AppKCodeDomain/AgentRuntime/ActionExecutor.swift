import Foundation
import AppKCodeShared

// MARK: - Action Executor Protocol (TASK-021.1)

public protocol ActionExecutor: Sendable {
    func execute(_ step: ActionStep, session: AgentSessionID) async throws -> ActionResult
}

// MARK: - Action Executor Impl (TASK-021.2~021.5, H12/H13/H14)

public final class ActionExecutorImpl: ActionExecutor, @unchecked Sendable {
    private let toolRegistry: ToolRegistry
    private let authGate: AuthorizationGate
    private let auditService: AuditService

    public init(toolRegistry: ToolRegistry, authGate: AuthorizationGate, auditService: AuditService) {
        self.toolRegistry = toolRegistry
        self.authGate = authGate
        self.auditService = auditService
    }

    public func execute(_ step: ActionStep, session: AgentSessionID) async throws -> ActionResult {
        guard let tool = toolRegistry.resolve(step.toolID) else {
            return .failure(ActionResultFailure(
                code: 404,
                message: "Tool not found: \(step.toolID.rawValue)",
                source: .toolInternal
            ))
        }

        let validation = tool.validate(arguments: step.arguments)
        if !validation.isValid {
            var reason = "Invalid arguments"
            if case .invalid(let r, _) = validation { reason = r }
            return .failure(ActionResultFailure(
                code: 400,
                message: reason,
                source: .invalidArguments
            ))
        }

        let decision = try await authGate.authorize(step, session: session)
        if !decision.isAllowed {
            var reason = "Authorization denied"
            if case .rejected(_, _, let r) = decision { reason = r }
            let result: ActionResult = .failure(ActionResultFailure(
                code: 403,
                message: reason,
                source: .authorizationRejected
            ))
            try await recordAudit(step: step, session: session, decision: decision, result: result)
            return result
        }

        let startTime = Date()
        do {
            let output = try await tool.execute(arguments: step.arguments, session: session)
            let duration = Date().timeIntervalSince(startTime)
            let evidenceID = EvidenceRecordID()
            let result: ActionResult = .success(ActionResultSuccess(
                output: output,
                evidenceID: evidenceID,
                durationSeconds: duration
            ))
            try await recordAudit(step: step, session: session, decision: decision, result: result)
            return result
        } catch {
            let result: ActionResult = .failure(ActionResultFailure(
                code: 500,
                message: error.localizedDescription,
                source: .underlyingError
            ))
            try await recordAudit(step: step, session: session, decision: decision, result: result)
            return result
        }
    }

    private func recordAudit(
        step: ActionStep,
        session: AgentSessionID,
        decision: AuthorizationDecision,
        result: ActionResult
    ) async throws {
        let resultSummary: AuditResultSummary
        switch result {
        case .success:
            resultSummary = .success
        case .failure(let f):
            resultSummary = .failure(code: f.code, message: f.message)
        case .timedOut:
            resultSummary = .timedOut
        case .cancelled:
            resultSummary = .cancelled
        }

        let target: AuditTarget = determineTarget(step: step)
        var error: String? = nil
        if case .failure(let f) = result { error = f.message }

        let record = AgentAuditRecord(
            sessionID: session,
            tool: step.toolID,
            arguments: step.arguments,
            target: target,
            approval: decision,
            result: resultSummary,
            error: error,
            sha256: "computed-by-store"
        )
        try await auditService.record(record)
    }

    private func determineTarget(step: ActionStep) -> AuditTarget {
        if let path = step.arguments.filePath("path") { return .filePath(path) }
        if let projectRoot = step.arguments.filePath("projectRoot") { return .filePath(projectRoot) }
        if let cmd = step.arguments.string("command") { return .command(cmd) }
        return .none
    }
}

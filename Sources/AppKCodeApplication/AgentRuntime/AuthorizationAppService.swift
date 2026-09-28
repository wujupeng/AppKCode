import Foundation
import AppKCodeShared
import AppKCodeDomain

// MARK: - Authorization Application Service (TASK-024)

public final class AuthorizationAppService: @unchecked Sendable {
    private let authGate: AuthorizationGate
    private let auditService: AuditService

    public init(authGate: AuthorizationGate, auditService: AuditService) {
        self.authGate = authGate
        self.auditService = auditService
    }

    public func requestAuthorization(
        _ step: ActionStep,
        session: AgentSessionID
    ) async throws -> AuthorizationDecision {
        try await authGate.authorize(step, session: session)
    }

    public func auditTrail(session: AgentSessionID) async throws -> [AgentAuditRecord] {
        let filter = AuditFilter(sessionID: session)
        return try await auditService.query(filter)
    }
}
import Foundation
import AppKCodeShared
import AppKCodeDomain

// MARK: - Audit Application Service (TASK-025)

public final class AuditAppService: @unchecked Sendable {
    private let auditService: AuditService

    public init(auditService: AuditService) {
        self.auditService = auditService
    }

    public func queryAuditTrail(_ filter: AuditFilter) async throws -> [AgentAuditRecord] {
        try await auditService.query(filter)
    }

    public func verifyIntegrity(session: AgentSessionID) async throws -> Bool {
        try await auditService.verifyIntegrity(session: session)
    }

    public func exportAuditTrail(session: AgentSessionID, to url: URL) async throws {
        let filter = AuditFilter(sessionID: session)
        let records = try await auditService.query(filter)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(records)
        try data.write(to: url)
    }
}
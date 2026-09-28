import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

// MARK: - Audit Service Protocol (TASK-020.1, H14)

public protocol AuditService: Sendable {
    func record(_ entry: AgentAuditRecord) async throws
    func query(_ filter: AuditFilter) async throws -> [AgentAuditRecord]
    func verifyIntegrity(session: AgentSessionID) async throws -> Bool
}

// MARK: - Audit Service Impl (TASK-020.2~020.4, H14)

public final class AuditServiceImpl: AuditService, @unchecked Sendable {
    private let logStore: AuditLogStore

    public init(logStore: AuditLogStore) {
        self.logStore = logStore
    }

    public func record(_ entry: AgentAuditRecord) async throws {
        try await logStore.append(entry)
    }

    public func query(_ filter: AuditFilter) async throws -> [AgentAuditRecord] {
        try await logStore.query(filter)
    }

    public func verifyIntegrity(session: AgentSessionID) async throws -> Bool {
        let filter = AuditFilter(sessionID: session)
        let records = try await logStore.query(filter)
        for record in records {
            let computed = AuditLogStore.computeSHA256(record)
            if computed != record.sha256 {
                return false
            }
        }
        return true
    }
}
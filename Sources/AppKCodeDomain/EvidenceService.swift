import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

public final class EvidenceService: DomainEvidenceService, @unchecked Sendable {
    private let store: JSONLEvidenceStore

    public init(store: JSONLEvidenceStore) {
        self.store = store
    }

    public func capture(_ record: EvidenceRecord) async throws {
        try await store.append(record)
    }

    public func chain(for session: AgentSessionID) async throws -> EvidenceChain {
        try await store.chain(for: session)
    }
}
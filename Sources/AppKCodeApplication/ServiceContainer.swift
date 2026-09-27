import Foundation
import AppKCodeShared
import AppKCodeDomain
import AppKCodeInfrastructure

public final class ServiceContainer: @unchecked Sendable {
    public let workspaceService: WorkspaceService
    public let modelRouter: ModelRouter
    public let sandboxManager: SandboxManager
    public let auditStore: JSONLAuditStore
    public let evidenceStore: JSONLEvidenceStore
    public let logger: StructuredLogger
    public let processRunner: ProcessRunner

    public init() {
        self.logger = StructuredLogger()
        self.sandboxManager = SandboxManager()
        self.auditStore = JSONLAuditStore()
        self.evidenceStore = JSONLEvidenceStore()
        self.processRunner = ProcessRunner()
        self.modelRouter = ModelRouter()
        self.workspaceService = WorkspaceService()
    }
}
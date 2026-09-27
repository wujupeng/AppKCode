import Foundation

public protocol AppAgentOrchestrator: Sendable {
    func createSession(projectRoot: URL) async throws -> AgentSessionID
    func submitRequest(_ request: AgentRequest, session: AgentSessionID) async throws -> AgentResponse
    func resumeSession(_ session: AgentSessionID) async throws
    func abortSession(_ session: AgentSessionID) async throws
}

public protocol AppApprovalService: Sendable {
    func classify(operation: OperationDescriptor) -> RiskLevel
    func requestApproval(_ payload: ApprovalPayload) async throws -> ApprovalDecision
    func auditTrail(session: AgentSessionID) async throws -> [AuditRecord]
}

public protocol AppToolRouter: Sendable {
    func execute(_ call: ToolCall, session: AgentSessionID) async throws -> ToolResult
}

public protocol DomainModelRouter: Sendable {
    func route(taskType: TaskType) -> ModelEndpoint
    func infer(_ request: InferenceRequest, taskType: TaskType) async throws -> InferenceResponse
}

public protocol DomainEvidenceService: Sendable {
    func capture(_ record: EvidenceRecord) async throws
    func chain(for session: AgentSessionID) async throws -> EvidenceChain
}

public protocol DomainCodebaseIndex: Sendable {
    func indexProject(root: URL) async throws
    func query(_ query: String) async throws -> [SearchHit]
}

public protocol DomainContractRegistry: Sendable {
    func register(_ contract: CompatibilityContract) throws
    func lookup(_ contractID: String) -> CompatibilityContract?
}

public protocol DomainLSPHost: Sendable {
    func startServer(language: String, projectRoot: URL) async throws
    func stopServer(language: String) async throws
}

public protocol InfraAuditStore: Sendable {
    func append(_ record: AuditRecord) async throws
    func query(filter: AuditQueryFilter) async throws -> [AuditRecord]
}

public struct AuditQueryFilter: Sendable, Equatable {
    public let sessionID: AgentSessionID?
    public let from: ISO8601Timestamp?
    public let to: ISO8601Timestamp?
    public init(sessionID: AgentSessionID? = nil, from: ISO8601Timestamp? = nil, to: ISO8601Timestamp? = nil) {
        self.sessionID = sessionID
        self.from = from
        self.to = to
    }
}

public protocol InfraEvidenceStore: Sendable {
    func append(_ record: EvidenceRecord) async throws
    func chain(for session: AgentSessionID) async throws -> EvidenceChain
}

public protocol InfraSandboxManager: Sendable {
    func createSandbox(session: AgentSessionID) throws -> URL
    func teardown(session: AgentSessionID) throws
}

public protocol InfraModelClient: Sendable {
    func chatCompletion(_ request: InferenceRequest, endpoint: ModelEndpoint) async throws -> InferenceResponse
}

public struct CompatibilityContract: Sendable, Equatable {
    public let contractID: String
    public let apiSurface: APISurface
    public let degradationStrategy: DegradationStrategy
    public init(contractID: String, apiSurface: APISurface, degradationStrategy: DegradationStrategy) {
        self.contractID = contractID
        self.apiSurface = apiSurface
        self.degradationStrategy = degradationStrategy
    }
}

public enum APISurface: Sendable, Equatable {
    case native
    case vscode
    case jetbrains
    case lsp
    case mcp
}

public enum DegradationStrategy: Sendable, Equatable {
    case unsupported
    case stub
    case fallback(String)
}
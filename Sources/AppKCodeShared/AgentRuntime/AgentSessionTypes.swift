import Foundation

// MARK: - Agent Session Status (TASK-001.2)

public enum AgentSessionStatus: String, Sendable, Codable {
    case active
    case paused
    case completed
    case aborted
}

// MARK: - Evidence Record ID (TASK-001.3 support)

public struct EvidenceRecordID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init() { self.rawValue = UUID().uuidString }
    public init(_ value: String) { self.rawValue = value }
}

// MARK: - Action Plan Snapshot (lightweight, for session persistence)

public struct ActionPlanSnapshot: Sendable, Codable {
    public let planID: ActionPlanID
    public let totalSteps: Int
    public let completedStepIDs: [ActionStepID]
    public let createdAt: ISO8601Timestamp

    public init(planID: ActionPlanID, totalSteps: Int, completedStepIDs: [ActionStepID], createdAt: ISO8601Timestamp) {
        self.planID = planID
        self.totalSteps = totalSteps
        self.completedStepIDs = completedStepIDs
        self.createdAt = createdAt
    }
}

// MARK: - Agent Session Snapshot (TASK-001.3)

public struct AgentSessionSnapshot: Sendable, Codable {
    public let id: AgentSessionID
    public let projectRoot: URL
    public let status: AgentSessionStatus
    public let createdAt: ISO8601Timestamp
    public let sandboxDir: URL
    public let plan: ActionPlanSnapshot?
    public let completedSteps: [ActionStepID]
    public let evidenceChain: [EvidenceRecordID]

    public init(
        id: AgentSessionID,
        projectRoot: URL,
        status: AgentSessionStatus,
        createdAt: ISO8601Timestamp,
        sandboxDir: URL,
        plan: ActionPlanSnapshot? = nil,
        completedSteps: [ActionStepID] = [],
        evidenceChain: [EvidenceRecordID] = []
    ) {
        self.id = id
        self.projectRoot = projectRoot
        self.status = status
        self.createdAt = createdAt
        self.sandboxDir = sandboxDir
        self.plan = plan
        self.completedSteps = completedSteps
        self.evidenceChain = evidenceChain
    }
}

// MARK: - Agent Session Error (TASK-001.4)

public enum AgentSessionError: Error, Sendable {
    case sessionNotFound(AgentSessionID)
    case sessionAlreadyActive(AgentSessionID)
    case sessionAborted(AgentSessionID)
    case sandboxCreationFailed(String)
    case invalidProjectRoot(URL)

    public var localizedDescription: String {
        switch self {
        case .sessionNotFound(let id):
            return "Agent session not found: \(id.rawValue)"
        case .sessionAlreadyActive(let id):
            return "Agent session already active: \(id.rawValue)"
        case .sessionAborted(let id):
            return "Agent session aborted: \(id.rawValue)"
        case .sandboxCreationFailed(let reason):
            return "Sandbox creation failed: \(reason)"
        case .invalidProjectRoot(let url):
            return "Invalid project root: \(url.path)"
        }
    }
}
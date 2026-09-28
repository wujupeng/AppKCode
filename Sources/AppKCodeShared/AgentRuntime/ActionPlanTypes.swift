import Foundation

// MARK: - Action Plan & Step IDs (TASK-002.1)

public struct ActionPlanID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init() { self.rawValue = UUID().uuidString }
    public init(_ value: String) { self.rawValue = value }
}

public struct ActionStepID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init() { self.rawValue = UUID().uuidString }
    public init(_ value: String) { self.rawValue = value }
}

// MARK: - Action Step Status (TASK-002.2)

public enum ActionStepStatus: String, Sendable, Codable {
    case pending
    case proposing
    case awaitingApproval
    case approved
    case rejected
    case executing
    case succeeded
    case failed
    case timedOut
    case cancelled
}

// MARK: - Action Priority (TASK-002.3)

public enum ActionPriority: Int, Sendable, Codable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    public static func < (lhs: ActionPriority, rhs: ActionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Action Step (TASK-002.4)

public struct ActionStep: Sendable, Codable {
    public let id: ActionStepID
    public let toolID: ToolID
    public let arguments: ToolArguments
    public let description: String
    public let explanation: String
    public let priority: ActionPriority
    public var dependsOn: [ActionStepID]
    public var status: ActionStepStatus
    public var result: ActionResultSnapshot?

    public init(
        id: ActionStepID = ActionStepID(),
        toolID: ToolID,
        arguments: ToolArguments,
        description: String,
        explanation: String,
        priority: ActionPriority = .medium,
        dependsOn: [ActionStepID] = [],
        status: ActionStepStatus = .pending,
        result: ActionResultSnapshot? = nil
    ) {
        self.id = id
        self.toolID = toolID
        self.arguments = arguments
        self.description = description
        self.explanation = explanation
        self.priority = priority
        self.dependsOn = dependsOn
        self.status = status
        self.result = result
    }
}

// MARK: - Action Plan (TASK-002.5)

public struct ActionPlan: Sendable, Codable {
    public let id: ActionPlanID
    public let sessionID: AgentSessionID
    public var steps: [ActionStep]
    public let createdAt: ISO8601Timestamp
    public var completedAt: ISO8601Timestamp?

    public init(
        id: ActionPlanID = ActionPlanID(),
        sessionID: AgentSessionID,
        steps: [ActionStep],
        createdAt: ISO8601Timestamp = ISO8601Timestamp(),
        completedAt: ISO8601Timestamp? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.steps = steps
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    public func nextExecutableStep() -> ActionStep? {
        let completedSet = Set(steps.filter { $0.status == .succeeded }.map { $0.id })
        let candidates = steps.filter { step in
            step.status == .pending
                && step.dependsOn.allSatisfy { completedSet.contains($0) }
        }
        return candidates.max(by: { $0.priority < $1.priority })
    }
}
import Foundation
import AppKCodeShared

// MARK: - M11-P1-TASK-001: G-AI 流程驱动值类型与枚举
// 对应需求: m11_design.md §2.2.2.1
// 对应硬约束: H28 (AI Execution Boundary 桥接基础)
// 所有类型均为 Sendable + Codable + Equatable

// MARK: - GAIWorkflowPhase

public enum GAIWorkflowPhase: String, Sendable, Codable, Equatable, CaseIterable {
    case spec
    case design
    case task
    case implementation
    case test
    case evidence
    case review
    case gate

    public func next() -> GAIWorkflowPhase? {
        switch self {
        case .spec: return .design
        case .design: return .task
        case .task: return .implementation
        case .implementation: return .test
        case .test: return .evidence
        case .evidence: return .review
        case .review: return .gate
        case .gate: return nil
        }
    }

    public var isHighRisk: Bool {
        switch self {
        case .implementation: return true
        default: return false
        }
    }
}

// MARK: - GAIWorkflowStatus

public enum GAIWorkflowStatus: String, Sendable, Codable, Equatable, CaseIterable {
    case pending
    case inProgress
    case awaitingApproval
    case completed
    case rejected
    case cancelled

    public var isTerminal: Bool {
        switch self {
        case .completed, .rejected, .cancelled: return true
        default: return false
        }
    }
}

// MARK: - GAIWorkflowTaskID

public struct GAIWorkflowTaskID: Sendable, Codable, Equatable, Hashable {
    public let value: UUID

    public init() {
        self.value = UUID()
    }

    public init(_ value: UUID) {
        self.value = value
    }
}

// MARK: - GAIWorkflowTask

public struct GAIWorkflowTask: Sendable, Codable, Equatable {
    public let id: GAIWorkflowTaskID
    public let phase: GAIWorkflowPhase
    public let userRequest: String
    public let contextRequest: String
    public let maxSteps: Int

    public init(
        id: GAIWorkflowTaskID = GAIWorkflowTaskID(),
        phase: GAIWorkflowPhase,
        userRequest: String,
        contextRequest: String,
        maxSteps: Int
    ) {
        self.id = id
        self.phase = phase
        self.userRequest = userRequest
        self.contextRequest = contextRequest
        self.maxSteps = maxSteps
    }
}

// MARK: - GAIWorkflowEvidence

public struct GAIWorkflowEvidence: Sendable, Codable, Equatable {
    public let phase: GAIWorkflowPhase
    public let evidenceType: String
    public let payload: String
    public let timestamp: ISO8601Timestamp

    public init(
        phase: GAIWorkflowPhase,
        evidenceType: String,
        payload: String,
        timestamp: ISO8601Timestamp = ISO8601Timestamp()
    ) {
        self.phase = phase
        self.evidenceType = evidenceType
        self.payload = payload
        self.timestamp = timestamp
    }
}

// MARK: - GateResult

public struct GateResult: Sendable, Codable, Equatable {
    public enum Verdict: String, Sendable, Codable, Equatable {
        case pass_
        case fail
    }

    public let verdict: Verdict
    public let summary: String
    public let timestamp: ISO8601Timestamp

    public init(
        verdict: Verdict,
        summary: String,
        timestamp: ISO8601Timestamp = ISO8601Timestamp()
    ) {
        self.verdict = verdict
        self.summary = summary
        self.timestamp = timestamp
    }
}

// MARK: - GAIWorkflowState

public struct GAIWorkflowState: Sendable, Codable, Equatable {
    public let sessionID: AgentSessionID
    public let taskID: GAIWorkflowTaskID
    public var currentPhase: GAIWorkflowPhase
    public var status: GAIWorkflowStatus
    public var evidenceChain: [GAIWorkflowEvidence]
    public var gateResult: GateResult?
    public var stepsTaken: Int

    public init(
        sessionID: AgentSessionID,
        taskID: GAIWorkflowTaskID,
        currentPhase: GAIWorkflowPhase,
        status: GAIWorkflowStatus = .pending,
        evidenceChain: [GAIWorkflowEvidence] = [],
        gateResult: GateResult? = nil,
        stepsTaken: Int = 0
    ) {
        self.sessionID = sessionID
        self.taskID = taskID
        self.currentPhase = currentPhase
        self.status = status
        self.evidenceChain = evidenceChain
        self.gateResult = gateResult
        self.stepsTaken = stepsTaken
    }
}
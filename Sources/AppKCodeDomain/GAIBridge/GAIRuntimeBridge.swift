import Foundation
import AppKCodeShared

// MARK: - M11-P1-TASK-002: GAIRuntimeBridge 协议
// 对应需求: m11_design.md §2.2.2.1
// 对应硬约束: H28 (AI Execution Boundary 桥接入口)
// GAIRuntimeBridge 是 G-AI Runtime 流程驱动的唯一桥接入口

// MARK: - GAIError

public enum GAIError: Error, Sendable, Equatable {
    case unknownPhase(phase: GAIWorkflowPhase)
    case maxStepsExceeded(taskID: GAIWorkflowTaskID, maxSteps: Int)
    case authorizationDenied(session: AgentSessionID)
    case sessionNotFound(session: AgentSessionID)
    case alreadyCompleted(taskID: GAIWorkflowTaskID)
    case invalidMaxSteps
    case inferenceFailed(reason: String)
}

// MARK: - GAIRuntimeBridge Protocol

public protocol GAIRuntimeBridge: Sendable {
    func submitTask(_ task: GAIWorkflowTask) async throws -> GAIWorkflowState
    func advance(phase: GAIWorkflowPhase, session: AgentSessionID) async throws -> GAIWorkflowState
    func currentState(session: AgentSessionID) async throws -> GAIWorkflowState
    func cancel(session: AgentSessionID) async throws
}
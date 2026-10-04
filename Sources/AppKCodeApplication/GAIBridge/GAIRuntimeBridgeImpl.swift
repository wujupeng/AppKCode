import Foundation
import AppKCodeShared
import AppKCodeDomain

// MARK: - M11-P1-TASK-003: GAIRuntimeBridgeImpl 实现
// 对应需求: m11_design.md §2.2.2.1
// 对应硬约束: H3 / H9 / H11 / H28-1
// 通过依赖注入复用 M6 ModelProviderRegistry + AIBoundaryValidator + M7 AgentRuntimeOrchestrator
// 不修改 M6 / M7 任何源文件

// MARK: - GAIRuntimeBridgeImpl

public final class GAIRuntimeBridgeImpl: GAIRuntimeBridge, @unchecked Sendable {

    private let modelProviderRegistry: ModelProviderRegistry
    private let aiBoundaryValidator: AIBoundaryValidator
    private let orchestrator: AgentRuntimeOrchestrator
    private let auditBridge: AIAuditBridge?

    private let stateLock = NSLock()
    private var sessions: [AgentSessionID: GAIWorkflowState] = [:]
    private var taskSessionMap: [GAIWorkflowTaskID: AgentSessionID] = [:]
    private var taskMaxSteps: [GAIWorkflowTaskID: Int] = [:]

    public init(
        modelProviderRegistry: ModelProviderRegistry,
        aiBoundaryValidator: AIBoundaryValidator,
        orchestrator: AgentRuntimeOrchestrator,
        auditBridge: AIAuditBridge? = nil
    ) {
        self.modelProviderRegistry = modelProviderRegistry
        self.aiBoundaryValidator = aiBoundaryValidator
        self.orchestrator = orchestrator
        self.auditBridge = auditBridge
    }

    // MARK: - submitTask

    public func submitTask(_ task: GAIWorkflowTask) async throws -> GAIWorkflowState {
        guard task.maxSteps > 0 else {
            throw GAIError.invalidMaxSteps
        }

        let decision = aiBoundaryValidator.validate(capability: .readContext)
        guard decision.allowed.contains(.readContext) else {
            throw GAIError.authorizationDenied(session: AgentSessionID())
        }

        let sessionID = AgentSessionID()

        let initialState = GAIWorkflowState(
            sessionID: sessionID,
            taskID: task.id,
            currentPhase: task.phase,
            status: .pending,
            evidenceChain: [],
            gateResult: nil,
            stepsTaken: 0
        )

        stateLock.lock()
        sessions[sessionID] = initialState
        taskSessionMap[task.id] = sessionID
        taskMaxSteps[task.id] = task.maxSteps
        stateLock.unlock()

        if let audit = auditBridge {
            try? await audit.record(AIAuditEvent(
                kind: .gaiWorkflowStarted,
                sessionID: sessionID,
                taskID: task.id,
                phase: task.phase,
                detail: "G-AI workflow started: \(task.userRequest)"
            ))
        }

        return initialState
    }

    // MARK: - advance

    public func advance(phase: GAIWorkflowPhase, session: AgentSessionID) async throws -> GAIWorkflowState {
        stateLock.lock()
        let currentState = sessions[session]
        stateLock.unlock()

        guard var state = currentState else {
            throw GAIError.sessionNotFound(session: session)
        }

        guard !state.status.isTerminal else {
            throw GAIError.alreadyCompleted(taskID: state.taskID)
        }

        guard let nextPhase = state.currentPhase.next(), nextPhase == phase else {
            throw GAIError.unknownPhase(phase: phase)
        }

        state.stepsTaken += 1

        stateLock.lock()
        let maxSteps = taskMaxSteps[state.taskID]
        stateLock.unlock()
        if let maxSteps = maxSteps, state.stepsTaken > maxSteps {
            state.status = .rejected
            stateLock.lock()
            sessions[session] = state
            stateLock.unlock()
            throw GAIError.maxStepsExceeded(taskID: state.taskID, maxSteps: maxSteps)
        }

        state.currentPhase = phase
        state.status = .inProgress

        if phase.isHighRisk {
            state.status = .awaitingApproval
        }

        let evidence = GAIWorkflowEvidence(
            phase: phase,
            evidenceType: "phaseAdvanced",
            payload: "Advanced to \(phase.rawValue)"
        )
        state.evidenceChain.append(evidence)

        stateLock.lock()
        sessions[session] = state
        stateLock.unlock()

        if let audit = auditBridge {
            try? await audit.record(AIAuditEvent(
                kind: .gaiWorkflowPhaseStarted,
                sessionID: session,
                taskID: state.taskID,
                phase: phase,
                detail: "Phase advanced to \(phase.rawValue)"
            ))
        }

        return state
    }

    // MARK: - currentState

    public func currentState(session: AgentSessionID) async throws -> GAIWorkflowState {
        stateLock.lock()
        let state = sessions[session]
        stateLock.unlock()

        guard let state = state else {
            throw GAIError.sessionNotFound(session: session)
        }
        return state
    }

    // MARK: - cancel

    public func cancel(session: AgentSessionID) async throws {
        stateLock.lock()
        let currentState = sessions[session]
        stateLock.unlock()

        guard var state = currentState else {
            throw GAIError.sessionNotFound(session: session)
        }

        state.status = .cancelled
        stateLock.lock()
        sessions[session] = state
        stateLock.unlock()

        await orchestrator.cancel(session: session)

        if let audit = auditBridge {
            try? await audit.record(AIAuditEvent(
                kind: .gaiWorkflowCancelled,
                sessionID: session,
                taskID: state.taskID,
                phase: state.currentPhase,
                detail: "Workflow cancelled"
            ))
        }
    }


}
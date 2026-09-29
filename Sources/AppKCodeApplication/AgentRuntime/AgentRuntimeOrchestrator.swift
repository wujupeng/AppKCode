import Foundation
import AppKCodeShared
import AppKCodeDomain

// MARK: - Agent Runtime Event (TASK-022.4)

public enum AgentRuntimeEvent: Sendable {
    case planCreated(ActionPlan)
    case stepProposing(ActionStep)
    case stepAwaitingApproval(ActionStep)
    case stepApproved(ActionStep)
    case stepExecuting(ActionStep)
    case stepCompleted(ActionStep, ActionResult)
    case stepFailed(ActionStep, ActionResult)
    case sessionCompleted(AgentSessionID)
    case ruleEnforced(stepID: ActionStepID, evaluation: RuleEvaluationResult)
}

// MARK: - Agent Runtime Orchestrator (TASK-022, H12)

public final class AgentRuntimeOrchestrator: @unchecked Sendable {
    private let planner: Planner
    private let sessionManager: AgentSessionManaging
    private let actionExecutor: ActionExecutor
    private let authGate: AuthorizationGate
    private let auditService: AuditService
    private let contextAggregator: ContextAggregator
    private let toolRegistry: ToolRegistry
    private let ruleEnforcer: RuleEnforcer?
    private let capabilityAppService: CapabilityAppService?

    public init(
        planner: Planner,
        sessionManager: AgentSessionManaging,
        actionExecutor: ActionExecutor,
        authGate: AuthorizationGate,
        auditService: AuditService,
        contextAggregator: ContextAggregator,
        toolRegistry: ToolRegistry,
        ruleEnforcer: RuleEnforcer? = nil,
        capabilityAppService: CapabilityAppService? = nil
    ) {
        self.planner = planner
        self.sessionManager = sessionManager
        self.actionExecutor = actionExecutor
        self.authGate = authGate
        self.auditService = auditService
        self.contextAggregator = contextAggregator
        self.toolRegistry = toolRegistry
        self.ruleEnforcer = ruleEnforcer
        self.capabilityAppService = capabilityAppService
    }

    public func runRequest(
        _ request: AgentRequest,
        session: AgentSessionID
    ) async throws -> AgentResponse {
        let snapshot = try await sessionManager.snapshot(session)
        let contextRequest = ContextRequest(projectRoot: snapshot.projectRoot)
        let context = try await contextAggregator.gather(context: contextRequest)
        let availableTools = toolRegistry.listAll()
        let plan = try await planner.generatePlan(
            userRequest: request.prompt,
            session: session,
            availableTools: availableTools,
            context: context
        )

        var effectivePlan = plan
        if let enforcer = ruleEnforcer {
            let enforced = enforcer.enforcePlan(plan, scope: .session)
            effectivePlan.steps = enforced.steps.filter { $0.allowed }.map { $0.step }
        }

        var results: [ActionResultSnapshot] = []
        var currentPlan = effectivePlan

        while let step = currentPlan.nextExecutableStep() {
            let result = try await actionExecutor.execute(step, session: session)
            let snapshot = ActionResultSnapshot(stepID: step.id, result: result)
            results.append(snapshot)

            if let idx = currentPlan.steps.firstIndex(where: { $0.id == step.id }) {
                currentPlan.steps[idx].status = result.isSuccess ? .succeeded : .failed
                currentPlan.steps[idx].result = snapshot
            }

            if !result.isSuccess {
                break
            }
        }

        let summary = results.map { sn in
            if sn.result.isSuccess { return "[OK] \(sn.stepID.rawValue)" }
            else { return "[FAIL] \(sn.stepID.rawValue)" }
        }.joined(separator: "\n")

        return AgentResponse(
            report: AgentReport(summary: "Completed \(results.count) steps", details: summary),
            evidenceChain: EvidenceChain(sessionID: session),
            proposedChanges: []
        )
    }

    public func runRequestStreaming(
        _ request: AgentRequest,
        session: AgentSessionID
    ) async throws -> AsyncThrowingStream<AgentRuntimeEvent, Error> {
        return AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.finish(throwing: AgentSessionError.sessionNotFound(session))
                    return
                }
                do {
                    let snapshot = try await self.sessionManager.snapshot(session)
                    let contextRequest = ContextRequest(projectRoot: snapshot.projectRoot)
                    let context = try await self.contextAggregator.gather(context: contextRequest)
                    let availableTools = self.toolRegistry.listAll()
                    let plan = try await self.planner.generatePlan(
                        userRequest: request.prompt,
                        session: session,
                        availableTools: availableTools,
                        context: context
                    )
                    continuation.yield(.planCreated(plan))

                    var effectivePlan = plan
                    if let enforcer = self.ruleEnforcer {
                        let enforced = enforcer.enforcePlan(plan, scope: .session)
                        for es in enforced.steps {
                            continuation.yield(.ruleEnforced(stepID: es.step.id, evaluation: es.evaluation))
                        }
                        effectivePlan.steps = enforced.steps.filter { $0.allowed }.map { $0.step }
                    }

                    var currentPlan = effectivePlan
                    while let step = currentPlan.nextExecutableStep() {
                        continuation.yield(.stepProposing(step))
                        continuation.yield(.stepAwaitingApproval(step))

                        let decision = try await self.authGate.authorize(step, session: session)
                        if decision.isAllowed {
                            continuation.yield(.stepApproved(step))
                        } else {
                            continuation.yield(.stepFailed(step, .failure(ActionResultFailure(
                                code: 403, message: "Authorization denied", source: .authorizationRejected
                            ))))
                            break
                        }

                        continuation.yield(.stepExecuting(step))
                        let result = try await self.actionExecutor.execute(step, session: session)

                        if result.isSuccess {
                            continuation.yield(.stepCompleted(step, result))
                        } else {
                            continuation.yield(.stepFailed(step, result))
                            break
                        }

                        if let idx = currentPlan.steps.firstIndex(where: { $0.id == step.id }) {
                            currentPlan.steps[idx].status = result.isSuccess ? .succeeded : .failed
                            currentPlan.steps[idx].result = ActionResultSnapshot(stepID: step.id, result: result)
                        }
                    }

                    continuation.yield(.sessionCompleted(session))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func cancel(session: AgentSessionID) async {
        // Cancellation propagated via Task.cancel() in calling code
    }
}
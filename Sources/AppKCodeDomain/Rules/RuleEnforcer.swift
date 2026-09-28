import Foundation
import AppKCodeShared

// MARK: - Enforced Plan (TASK-021.2)

public struct EnforcedStep: Sendable {
    public let step: ActionStep
    public let evaluation: RuleEvaluationResult
    public let allowed: Bool
    public let warning: String?

    public init(step: ActionStep, evaluation: RuleEvaluationResult, allowed: Bool, warning: String? = nil) {
        self.step = step
        self.evaluation = evaluation
        self.allowed = allowed
        self.warning = warning
    }
}

public struct EnforcedPlan: Sendable {
    public let originalPlan: ActionPlan
    public let steps: [EnforcedStep]

    public init(originalPlan: ActionPlan, steps: [EnforcedStep]) {
        self.originalPlan = originalPlan
        self.steps = steps
    }
}

// MARK: - Rule Enforcer (TASK-021)

public final class RuleEnforcer: @unchecked Sendable {
    private let ruleEngine: RuleEngine
    private let ruleResolver: RuleResolver

    public init(ruleEngine: RuleEngine, ruleResolver: RuleResolver) {
        self.ruleEngine = ruleEngine
        self.ruleResolver = ruleResolver
    }

    public func enforcePlan(_ plan: ActionPlan, scope: RuleScope) -> EnforcedPlan {
        let enforcedSteps = plan.steps.map { step in
            enforceStep(step, scope: scope)
        }

        return EnforcedPlan(originalPlan: plan, steps: enforcedSteps)
    }

    public func enforceStep(_ step: ActionStep, scope: RuleScope) -> EnforcedStep {
        let target = RuleTarget.toolID(step.toolID)
        let evaluation = ruleEngine.evaluate(target: target, scope: scope)

        switch evaluation {
        case .block(let ruleID, let message):
            return EnforcedStep(
                step: step,
                evaluation: evaluation,
                allowed: false,
                warning: "Blocked by rule \(ruleID.rawValue): \(message)"
            )
        case .warn(let ruleID, let message):
            return EnforcedStep(
                step: step,
                evaluation: evaluation,
                allowed: true,
                warning: "Warning from rule \(ruleID.rawValue): \(message)"
            )

        case .allow:
            return EnforcedStep(step: step, evaluation: evaluation, allowed: true)
        case .noApplicableRule:
            return EnforcedStep(step: step, evaluation: evaluation, allowed: true)
        }
    }
}
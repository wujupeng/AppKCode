import Foundation
import AppKCodeShared
import AppKCodeDomain

// MARK: - Rule App Service (TASK-026)

public final class RuleAppService: @unchecked Sendable {
    private let ruleEngine: RuleEngine
    private let ruleResolver: RuleResolver
    private let ruleEnforcer: RuleEnforcer

    public init(ruleEngine: RuleEngine, ruleResolver: RuleResolver, ruleEnforcer: RuleEnforcer) {
        self.ruleEngine = ruleEngine
        self.ruleResolver = ruleResolver
        self.ruleEnforcer = ruleEnforcer
    }

    public func listRules() -> [Rule] {
        ruleEngine.currentRuleSet().rules
    }

    public func ruleConflicts() -> [RuleConflict] {
        ruleEngine.detectConflicts(ruleSet: ruleEngine.currentRuleSet())
    }

    public func resolveConflicts() -> [RuleResolution] {
        let conflicts = ruleConflicts()
        return ruleResolver.resolve(conflicts, ruleSet: ruleEngine.currentRuleSet())
    }

    public func enforcePlan(_ plan: ActionPlan, scope: RuleScope) -> EnforcedPlan {
        ruleEnforcer.enforcePlan(plan, scope: scope)
    }

    public func updateRuleSet(_ ruleSet: RuleSet) throws {
        try ruleEngine.updateRuleSet(ruleSet)
    }
}
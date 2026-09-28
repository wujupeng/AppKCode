import Foundation
import AppKCodeShared

// MARK: - Rule Resolver (TASK-020, H17)

public final class RuleResolver: @unchecked Sendable {
    public init() {}

    public func resolve(_ conflicts: [RuleConflict], ruleSet: RuleSet) -> [RuleResolution] {
        conflicts.map { conflict in
            resolveConflict(conflict, ruleSet: ruleSet)
        }
    }

    private func resolveConflict(_ conflict: RuleConflict, ruleSet: RuleSet) -> RuleResolution {
        let r1 = ruleSet.rules.first { $0.id == conflict.rule1 }
        let r2 = ruleSet.rules.first { $0.id == conflict.rule2 }

        switch conflict.conflictType {
        case .contradictoryInstruction:
            return RuleResolution(
                conflict: conflict,
                strategy: .denyByDefault,
                resolvedRuleID: pickBlockRule(r1, r2),
                description: "Contradictory instructions resolved by deny-by-default (block wins)"
            )

        case .sameTargetDifferentEnforcement:
            if let r1 = r1, let r2 = r2 {
                if r1.scope > r2.scope {
                    return RuleResolution(
                        conflict: conflict,
                        strategy: .higherScopeWins,
                        resolvedRuleID: r1.id,
                        description: "Higher scope rule '\(r1.name)' wins"
                    )
                } else if r2.scope > r1.scope {
                    return RuleResolution(
                        conflict: conflict,
                        strategy: .higherScopeWins,
                        resolvedRuleID: r2.id,
                        description: "Higher scope rule '\(r2.name)' wins"
                    )
                } else if r1.priority > r2.priority {
                    return RuleResolution(
                        conflict: conflict,
                        strategy: .higherPriorityWins,
                        resolvedRuleID: r1.id,
                        description: "Higher priority rule '\(r1.name)' wins"
                    )
                } else {
                    return RuleResolution(
                        conflict: conflict,
                        strategy: .higherPriorityWins,
                        resolvedRuleID: r2.id,
                        description: "Higher priority rule '\(r2.name)' wins"
                    )
                }
            }
            return RuleResolution(
                conflict: conflict,
                strategy: .denyByDefault,
                resolvedRuleID: nil,
                description: "Unable to resolve: rules not found"
            )

        case .priorityCycle:
            return RuleResolution(
                conflict: conflict,
                strategy: .manualOverride,
                resolvedRuleID: nil,
                description: "Priority cycle detected: manual intervention required"
            )
        }
    }

    private func pickBlockRule(_ r1: Rule?, _ r2: Rule?) -> RuleID? {
        if let r1 = r1, r1.enforcement == .block { return r1.id }
        if let r2 = r2, r2.enforcement == .block { return r2.id }
        return r1?.id
    }
}
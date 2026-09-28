import Foundation
import AppKCodeShared

// MARK: - Rule Engine (TASK-019, H17)

public final class RuleEngine: @unchecked Sendable {
    private var ruleSet: RuleSet
    private let lock = NSLock()
    public let strictConflictDetection: Bool

    public init(ruleSet: RuleSet = RuleSet(), strictConflictDetection: Bool = true) {
        self.ruleSet = ruleSet
        self.strictConflictDetection = strictConflictDetection
    }

    public func evaluate(target: RuleTarget, scope: RuleScope) -> RuleEvaluationResult {
        lock.lock()
        let rules = ruleSet.rules
        lock.unlock()

        let matchingRules = rules.filter { rule in
            rule.scope <= scope && matchesCondition(rule.condition, target: target)
        }

        guard !matchingRules.isEmpty else {
            return .noApplicableRule
        }

        let sorted = matchingRules.sorted { r1, r2 in
            if r1.scope != r2.scope {
                return r1.scope > r2.scope
            }
            return r1.priority > r2.priority
        }

        let topRule = sorted[0]

        switch topRule.enforcement {
        case .block:
            return .block(rule: topRule.id, message: topRule.instruction.description)
        case .warn:
            return .warn(rule: topRule.id, message: topRule.instruction.description)
        case .info:
            return .allow
        }
    }

    public func detectConflicts(ruleSet: RuleSet) -> [RuleConflict] {
        var conflicts: [RuleConflict] = []

        for i in 0..<ruleSet.rules.count {
            for j in (i+1)..<ruleSet.rules.count {
                let r1 = ruleSet.rules[i]
                let r2 = ruleSet.rules[j]

                if targetsOverlap(r1.condition.target, r2.condition.target) {
                    if isContradictory(r1, r2) {
                        conflicts.append(RuleConflict(
                            rule1: r1.id,
                            rule2: r2.id,
                            conflictType: .contradictoryInstruction,
                            description: "Rules '\(r1.name)' and '\(r2.name)' have contradictory instructions"
                        ))
                    }

                    if r1.enforcement != r2.enforcement && r1.scope == r2.scope && r1.priority == r2.priority {
                        conflicts.append(RuleConflict(
                            rule1: r1.id,
                            rule2: r2.id,
                            conflictType: .sameTargetDifferentEnforcement,
                            description: "Rules '\(r1.name)' and '\(r2.name)' have different enforcement at same priority"
                        ))
                    }
                }
            }
        }

        return conflicts
    }

    public func updateRuleSet(_ newRuleSet: RuleSet) throws {
        let conflicts = detectConflicts(ruleSet: newRuleSet)
        if !conflicts.isEmpty && strictConflictDetection {
            throw RuleEngineError.unresolvedConflicts(conflicts)
        }
        lock.lock()
        ruleSet = newRuleSet
        lock.unlock()
    }

    public func currentRuleSet() -> RuleSet {
        lock.lock()
        defer { lock.unlock() }
        return ruleSet
    }

    private func matchesCondition(_ condition: RuleCondition, target: RuleTarget) -> Bool {
        if case .all = condition.target { return true }

        switch (condition.target, target) {
        case (.toolID(let ruleID), .toolID(let evalID)):
            return ruleID == evalID
        case (.toolCategory(let ruleCat), .toolCategory(let evalCat)):
            return ruleCat == evalCat
        case (.operationKind(let ruleKind), .operationKind(let evalKind)):
            return matchValue(condition.matcher, actual: evalKind)
        case (.all, _):
            return true
        default:
            return false
        }
    }

    private func matchValue(_ matcher: RuleMatcher, actual: String) -> Bool {
        switch matcher {
        case .equals(let v): return v == actual
        case .contains(let v): return actual.contains(v)
        case .regex(let v): return actual.range(of: v, options: .regularExpression) != nil
        case .always: return true
        }
    }

    private func targetsOverlap(_ a: RuleTarget, _ b: RuleTarget) -> Bool {
        if case .all = a { return true }
        if case .all = b { return true }
        return a == b
    }

    private func isContradictory(_ r1: Rule, _ r2: Rule) -> Bool {
        if r1.instruction.denyExecution && !r2.instruction.denyExecution {
            return true
        }
        if !r1.instruction.denyExecution && r2.instruction.denyExecution {
            return true
        }
        return false
    }
}

// MARK: - Rule Engine Error

public enum RuleEngineError: Error, Sendable {
    case unresolvedConflicts([RuleConflict])
    case invalidRuleSet(String)
}
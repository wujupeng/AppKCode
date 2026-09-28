import XCTest
@testable import AppKCodeDomain
import AppKCodeShared

final class RuleResolverTests: XCTestCase {
    func testResolveContradictoryInstruction() {
        let r1 = Rule(
            name: "allow",
            scope: .global,
            priority: RulePriority(10),
            condition: RuleCondition(target: .all, matcher: .always),
            instruction: RuleInstruction(description: "Allow", denyExecution: false),
            enforcement: .info
        )
        let r2 = Rule(
            name: "block",
            scope: .global,
            priority: RulePriority(10),
            condition: RuleCondition(target: .all, matcher: .always),
            instruction: RuleInstruction(description: "Block", denyExecution: true),
            enforcement: .block
        )

        let conflict = RuleConflict(rule1: r1.id, rule2: r2.id, conflictType: .contradictoryInstruction, description: "Test")
        let resolver = RuleResolver()
        let resolutions = resolver.resolve([conflict], ruleSet: RuleSet(rules: [r1, r2]))

        XCTAssertEqual(resolutions.count, 1)
        XCTAssertEqual(resolutions[0].strategy, .denyByDefault, "Contradictory instructions should resolve to denyByDefault")
    }

    func testResolveSameTargetDifferentEnforcement() {
        let r1 = Rule(
            name: "warn",
            scope: .global,
            priority: RulePriority(5),
            condition: RuleCondition(target: .all, matcher: .always),
            instruction: RuleInstruction(description: "Warn"),
            enforcement: .warn
        )
        let r2 = Rule(
            name: "block",
            scope: .global,
            priority: RulePriority(10),
            condition: RuleCondition(target: .all, matcher: .always),
            instruction: RuleInstruction(description: "Block"),
            enforcement: .block
        )

        let conflict = RuleConflict(rule1: r1.id, rule2: r2.id, conflictType: .sameTargetDifferentEnforcement, description: "Test")
        let resolver = RuleResolver()
        let resolutions = resolver.resolve([conflict], ruleSet: RuleSet(rules: [r1, r2]))

        XCTAssertEqual(resolutions.count, 1)
        XCTAssertEqual(resolutions[0].strategy, .higherPriorityWins)
        XCTAssertEqual(resolutions[0].resolvedRuleID, r2.id, "Higher priority rule should win")
    }

    func testResolvePriorityCycle() {
        let r1 = Rule(name: "r1", scope: .global, priority: RulePriority(10), condition: RuleCondition(target: .all, matcher: .always), instruction: RuleInstruction(description: "R1"), enforcement: .block)
        let r2 = Rule(name: "r2", scope: .global, priority: RulePriority(10), condition: RuleCondition(target: .all, matcher: .always), instruction: RuleInstruction(description: "R2"), enforcement: .block)

        let conflict = RuleConflict(rule1: r1.id, rule2: r2.id, conflictType: .priorityCycle, description: "Cycle")
        let resolver = RuleResolver()
        let resolutions = resolver.resolve([conflict], ruleSet: RuleSet(rules: [r1, r2]))

        XCTAssertEqual(resolutions[0].strategy, .manualOverride, "Priority cycle should require manual override")
    }
}
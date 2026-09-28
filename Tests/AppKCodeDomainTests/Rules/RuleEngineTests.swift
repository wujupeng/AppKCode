import XCTest
@testable import AppKCodeDomain
import AppKCodeShared

final class RuleEngineTests: XCTestCase {
    func testEvaluateNoApplicableRule() {
        let engine = RuleEngine(ruleSet: RuleSet())
        let result = engine.evaluate(target: .all, scope: .global)
        XCTAssertEqual(result, .noApplicableRule)
    }

    func testEvaluateBlockRule() {
        let rule = Rule(
            name: "block-git-push",
            scope: .global,
            priority: RulePriority(10),
            condition: RuleCondition(target: .all, matcher: .always),
            instruction: RuleInstruction(description: "Block git push", denyExecution: true),
            enforcement: .block
        )
        let engine = RuleEngine(ruleSet: RuleSet(rules: [rule]))
        let result = engine.evaluate(target: .all, scope: .global)

        if case .block(let ruleID, _) = result {
            XCTAssertEqual(ruleID, rule.id)
        } else {
            XCTFail("Expected block result")
        }
    }

    func testEvaluateWarnRule() {
        let rule = Rule(
            name: "warn-large-files",
            scope: .global,
            priority: RulePriority(5),
            condition: RuleCondition(target: .all, matcher: .always),
            instruction: RuleInstruction(description: "Warning"),
            enforcement: .warn
        )
        let engine = RuleEngine(ruleSet: RuleSet(rules: [rule]))
        let result = engine.evaluate(target: .all, scope: .global)

        if case .warn = result {
        } else {
            XCTFail("Expected warn result")
        }
    }

    func testH17ScopePriority() {
        let globalRule = Rule(
            name: "global-allow",
            scope: .global,
            priority: RulePriority(100),
            condition: RuleCondition(target: .all, matcher: .always),
            instruction: RuleInstruction(description: "Global allow"),
            enforcement: .info
        )
        let sessionRule = Rule(
            name: "session-block",
            scope: .session,
            priority: RulePriority(1),
            condition: RuleCondition(target: .all, matcher: .always),
            instruction: RuleInstruction(description: "Session block", denyExecution: true),
            enforcement: .block
        )

        let engine = RuleEngine(ruleSet: RuleSet(rules: [globalRule, sessionRule]))
        let result = engine.evaluate(target: .all, scope: .session)

        if case .block(let ruleID, _) = result {
            XCTAssertEqual(ruleID, sessionRule.id, "H17: session scope should override global scope regardless of priority")
        } else {
            XCTFail("Expected block from session scope rule")
        }
    }

    func testH17PriorityWithinSameScope() {
        let lowPriority = Rule(
            name: "low-priority-allow",
            scope: .global,
            priority: RulePriority(1),
            condition: RuleCondition(target: .all, matcher: .always),
            instruction: RuleInstruction(description: "Allow"),
            enforcement: .info
        )
        let highPriority = Rule(
            name: "high-priority-block",
            scope: .global,
            priority: RulePriority(100),
            condition: RuleCondition(target: .all, matcher: .always),
            instruction: RuleInstruction(description: "Block", denyExecution: true),
            enforcement: .block
        )

        let engine = RuleEngine(ruleSet: RuleSet(rules: [lowPriority, highPriority]))
        let result = engine.evaluate(target: .all, scope: .global)

        if case .block(let ruleID, _) = result {
            XCTAssertEqual(ruleID, highPriority.id, "H17: higher priority rule should win within same scope")
        } else {
            XCTFail("Expected block from higher priority rule")
        }
    }

    func testH17ConflictDetection() {
        let rule1 = Rule(
            name: "allow-rule",
            scope: .global,
            priority: RulePriority(10),
            condition: RuleCondition(target: .all, matcher: .always),
            instruction: RuleInstruction(description: "Allow", denyExecution: false),
            enforcement: .info
        )
        let rule2 = Rule(
            name: "block-rule",
            scope: .global,
            priority: RulePriority(10),
            condition: RuleCondition(target: .all, matcher: .always),
            instruction: RuleInstruction(description: "Block", denyExecution: true),
            enforcement: .block
        )

        let engine = RuleEngine(ruleSet: RuleSet())
        let conflicts = engine.detectConflicts(ruleSet: RuleSet(rules: [rule1, rule2]))

        XCTAssertGreaterThan(conflicts.count, 0, "H17: contradictory rules should be detected as conflicts")
    }

    func testH17StrictConflictDetection() {
        let rule1 = Rule(
            name: "allow-rule",
            scope: .global,
            priority: RulePriority(10),
            condition: RuleCondition(target: .all, matcher: .always),
            instruction: RuleInstruction(description: "Allow", denyExecution: false),
            enforcement: .info
        )
        let rule2 = Rule(
            name: "block-rule",
            scope: .global,
            priority: RulePriority(10),
            condition: RuleCondition(target: .all, matcher: .always),
            instruction: RuleInstruction(description: "Block", denyExecution: true),
            enforcement: .block
        )

        let engine = RuleEngine(strictConflictDetection: true)
        XCTAssertThrowsError(try engine.updateRuleSet(RuleSet(rules: [rule1, rule2]))) { error in
            guard case RuleEngineError.unresolvedConflicts = error else {
                XCTFail("Expected unresolvedConflicts error")
                return
            }
        }
    }

    func testRuleScopeOrdering() {
        XCTAssertTrue(RuleScope.session > RuleScope.project, "session > project")
        XCTAssertTrue(RuleScope.project > RuleScope.global, "project > global")
        XCTAssertTrue(RuleScope.session > RuleScope.global, "session > global")
    }

    func testRuleEnforcerBlock() {
        let rule = Rule(
            name: "block-all",
            scope: .global,
            priority: RulePriority(10),
            condition: RuleCondition(target: .all, matcher: .always),
            instruction: RuleInstruction(description: "Block all", denyExecution: true),
            enforcement: .block
        )
        let engine = RuleEngine(ruleSet: RuleSet(rules: [rule]))
        let resolver = RuleResolver()
        let enforcer = RuleEnforcer(ruleEngine: engine, ruleResolver: resolver)

        let step = ActionStep(toolID: ToolID("test.tool"), arguments: ToolArguments(), description: "Test", explanation: "Test")
        let enforced = enforcer.enforceStep(step, scope: .global)

        XCTAssertFalse(enforced.allowed, "Block rule should set allowed=false")
    }

    func testRuleEnforcerAllow() {
        let engine = RuleEngine(ruleSet: RuleSet())
        let resolver = RuleResolver()
        let enforcer = RuleEnforcer(ruleEngine: engine, ruleResolver: resolver)

        let step = ActionStep(toolID: ToolID("test.tool"), arguments: ToolArguments(), description: "Test", explanation: "Test")
        let enforced = enforcer.enforceStep(step, scope: .global)

        XCTAssertTrue(enforced.allowed, "No rules should allow the step")
    }
}
import XCTest
@testable import AppKCodeDomain
import AppKCodeShared

final class RuleEnforcerTests: XCTestCase {
    func testEnforcePlanFiltersBlockedSteps() {
        let blockRule = Rule(
            name: "block-specific-tool",
            scope: .global,
            priority: RulePriority(100),
            condition: RuleCondition(target: .toolID(ToolID("dangerous.tool")), matcher: .always),
            instruction: RuleInstruction(description: "Block dangerous tool", denyExecution: true),
            enforcement: .block
        )

        let engine = RuleEngine(ruleSet: RuleSet(rules: [blockRule]))
        let resolver = RuleResolver()
        let enforcer = RuleEnforcer(ruleEngine: engine, ruleResolver: resolver)

        let step1 = ActionStep(toolID: ToolID("safe.tool"), arguments: ToolArguments(), description: "Safe", explanation: "Safe step")
        let step2 = ActionStep(toolID: ToolID("dangerous.tool"), arguments: ToolArguments(), description: "Dangerous", explanation: "Dangerous step")
        let plan = ActionPlan(sessionID: AgentSessionID(), steps: [step1, step2])

        let enforced = enforcer.enforcePlan(plan, scope: .global)

        XCTAssertEqual(enforced.steps.count, 2)
        XCTAssertTrue(enforced.steps[0].allowed, "Safe step should be allowed")
        XCTAssertFalse(enforced.steps[1].allowed, "Dangerous step should be blocked")
    }

    func testEnforcePlanWarnDoesNotBlock() {
        let warnRule = Rule(
            name: "warn-tool",
            scope: .global,
            priority: RulePriority(10),
            condition: RuleCondition(target: .all, matcher: .always),
            instruction: RuleInstruction(description: "Warning"),
            enforcement: .warn
        )

        let engine = RuleEngine(ruleSet: RuleSet(rules: [warnRule]))
        let resolver = RuleResolver()
        let enforcer = RuleEnforcer(ruleEngine: engine, ruleResolver: resolver)

        let step = ActionStep(toolID: ToolID("any.tool"), arguments: ToolArguments(), description: "Any", explanation: "Any step")
        let plan = ActionPlan(sessionID: AgentSessionID(), steps: [step])

        let enforced = enforcer.enforcePlan(plan, scope: .global)

        XCTAssertTrue(enforced.steps[0].allowed, "Warn should not block execution")
        XCTAssertNotNil(enforced.steps[0].warning, "Warn should produce a warning message")
    }
}
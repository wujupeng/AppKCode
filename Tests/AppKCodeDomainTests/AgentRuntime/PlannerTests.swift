import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain

final class PlannerTests: XCTestCase {
    func testActionPlanNextExecutableStep() {
        let step1 = ActionStep(toolID: ToolID("a"), arguments: ToolArguments(), description: "Step 1", explanation: "", priority: .high)
        let step2 = ActionStep(toolID: ToolID("b"), arguments: ToolArguments(), description: "Step 2", explanation: "", priority: .medium, dependsOn: [step1.id])
        let plan = ActionPlan(sessionID: AgentSessionID(), steps: [step1, step2])
        let next = plan.nextExecutableStep()
        XCTAssertEqual(next?.id, step1.id)
    }

    func testActionPlanDependencyOrdering() {
        let step1 = ActionStep(toolID: ToolID("a"), arguments: ToolArguments(), description: "Step 1", explanation: "", priority: .low)
        let step2 = ActionStep(toolID: ToolID("b"), arguments: ToolArguments(), description: "Step 2", explanation: "", priority: .high, dependsOn: [step1.id])
        let plan = ActionPlan(sessionID: AgentSessionID(), steps: [step1, step2])
        let next = plan.nextExecutableStep()
        XCTAssertEqual(next?.id, step1.id)
    }

    func testActionPriorityOrdering() {
        XCTAssertLessThan(ActionPriority.low, ActionPriority.medium)
        XCTAssertLessThan(ActionPriority.medium, ActionPriority.high)
        XCTAssertLessThan(ActionPriority.high, ActionPriority.critical)
    }

    func testActionStepStatusAllCases() {
        let statuses: [ActionStepStatus] = [.pending, .proposing, .awaitingApproval, .approved, .rejected, .executing, .succeeded, .failed, .timedOut, .cancelled]
        XCTAssertEqual(statuses.count, 10)
    }

    func testActionPlanCodable() throws {
        let plan = ActionPlan(
            sessionID: AgentSessionID(),
            steps: [ActionStep(toolID: ToolID("test"), arguments: ToolArguments(), description: "Test", explanation: "")]
        )
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(ActionPlan.self, from: data)
        XCTAssertEqual(plan.id, decoded.id)
        XCTAssertEqual(plan.steps.count, decoded.steps.count)
    }

    func testToolSchemaTypesCodable() throws {
        let schema = ToolSchema(
            id: ToolID("test"),
            category: .fileRead,
            permission: .readOnly,
            parameters: [ToolParameterSchema(name: "path", type: .filePath, required: true, description: "Path")],
            returnType: .string,
            description: "Test tool",
            version: "1.0.0"
        )
        let data = try JSONEncoder().encode(schema)
        let decoded = try JSONDecoder().decode(ToolSchema.self, from: data)
        XCTAssertEqual(schema.id, decoded.id)
        XCTAssertEqual(schema.permission, decoded.permission)
    }

    func testToolValueCodable() throws {
        let values: [ToolValue] = [.string("hello"), .integer(42), .boolean(true), .array([.string("a"), .string("b")])]
        for value in values {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(ToolValue.self, from: data)
            XCTAssertEqual(value, decoded)
        }
    }
}
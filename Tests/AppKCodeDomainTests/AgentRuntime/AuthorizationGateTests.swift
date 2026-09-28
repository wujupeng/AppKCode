import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain

// Mock ApprovalService for testing
private final class MockApprovalService: AppApprovalService {
    var nextDecision: ApprovalDecision = .allow
    func classify(operation: OperationDescriptor) -> RiskLevel { .high }
    func requestApproval(_ payload: ApprovalPayload) async throws -> ApprovalDecision { nextDecision }
    func auditTrail(session: AgentSessionID) async throws -> [AuditRecord] { [] }
}

private final class MockToolForAuth: AgentTool {
    let schema: ToolSchema
    init(permission: ToolPermission) {
        self.schema = ToolSchema(
            id: ToolID("auth.test"), category: .fileRead, permission: permission,
            parameters: [], returnType: .string, description: "Auth test", version: "1.0.0"
        )
    }
    func validate(arguments: ToolArguments) -> ValidationResult { .valid }
    func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput { ToolOutput(text: "ok") }
}

final class AuthorizationGateTests: XCTestCase {
    func testReadOnlyAutoAllowed() async throws {
        let registry = ToolRegistry()
        try registry.register(MockToolForAuth(permission: .readOnly))
        let gate = AuthorizationGateImpl(approvalService: MockApprovalService(), toolRegistry: registry)
        let step = ActionStep(toolID: ToolID("auth.test"), arguments: ToolArguments(), description: "Read", explanation: "")
        let decision = try await gate.authorize(step, session: AgentSessionID())
        XCTAssertTrue(decision.isAllowed)
    }

    func testLowAutoAllowed() async throws {
        let registry = ToolRegistry()
        try registry.register(MockToolForAuth(permission: .low))
        let gate = AuthorizationGateImpl(approvalService: MockApprovalService(), toolRegistry: registry)
        let step = ActionStep(toolID: ToolID("auth.test"), arguments: ToolArguments(), description: "Low", explanation: "")
        let decision = try await gate.authorize(step, session: AgentSessionID())
        XCTAssertTrue(decision.isAllowed)
    }

    func testHighRequiresApproval() async throws {
        let registry = ToolRegistry()
        try registry.register(MockToolForAuth(permission: .high))
        let mockApproval = MockApprovalService()
        mockApproval.nextDecision = .allow
        let gate = AuthorizationGateImpl(approvalService: mockApproval, toolRegistry: registry)
        let step = ActionStep(toolID: ToolID("auth.test"), arguments: ToolArguments(), description: "Write", explanation: "")
        let decision = try await gate.authorize(step, session: AgentSessionID())
        XCTAssertTrue(decision.isAllowed)
    }

    func testHighRejectedWhenApprovalRejects() async throws {
        let registry = ToolRegistry()
        try registry.register(MockToolForAuth(permission: .high))
        let mockApproval = MockApprovalService()
        mockApproval.nextDecision = .reject
        let gate = AuthorizationGateImpl(approvalService: mockApproval, toolRegistry: registry)
        let step = ActionStep(toolID: ToolID("auth.test"), arguments: ToolArguments(), description: "Write", explanation: "")
        let decision = try await gate.authorize(step, session: AgentSessionID())
        XCTAssertTrue(decision.isRejected)
    }

    // H12: No bypass path — unknown tool is rejected
    func testH12UnknownToolRejected() async throws {
        let registry = ToolRegistry()
        let gate = AuthorizationGateImpl(approvalService: MockApprovalService(), toolRegistry: registry)
        let step = ActionStep(toolID: ToolID("unknown"), arguments: ToolArguments(), description: "Unknown", explanation: "")
        let decision = try await gate.authorize(step, session: AgentSessionID())
        XCTAssertTrue(decision.isRejected)
    }
}
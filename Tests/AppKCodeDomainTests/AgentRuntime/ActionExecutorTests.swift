import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain

private final class MockToolForExecutor: AgentTool {
    let schema: ToolSchema
    var shouldFail = false
    init(permission: ToolPermission = .readOnly) {
        self.schema = ToolSchema(
            id: ToolID("exec.test"), category: .fileRead, permission: permission,
            parameters: [], returnType: .string, description: "Exec test", version: "1.0.0"
        )
    }
    func validate(arguments: ToolArguments) -> ValidationResult { .valid }
    func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput {
        if shouldFail { throw AppKError.toolExecutionFailed(tool: "exec.test", cause: "mock failure") }
        return ToolOutput(text: "executed")
    }
}

private final class MockAuthGate: AuthorizationGate {
    var decision: AuthorizationDecision = .allowed(decidedBy: UserID("test"), at: ISO8601Timestamp(), sha256: "")
    func authorize(_ step: ActionStep, session: AgentSessionID) async throws -> AuthorizationDecision { decision }
}

private final class MockAuditSvc: AuditService {
    var recorded: [AgentAuditRecord] = []
    func record(_ entry: AgentAuditRecord) async throws { recorded.append(entry) }
    func query(_ filter: AuditFilter) async throws -> [AgentAuditRecord] { recorded }
    func verifyIntegrity(session: AgentSessionID) async throws -> Bool { true }
}

final class ActionExecutorTests: XCTestCase {
    func testExecuteSuccess() async throws {
        let registry = ToolRegistry()
        let tool = MockToolForExecutor()
        try registry.register(tool)
        let executor = ActionExecutorImpl(toolRegistry: registry, authGate: MockAuthGate(), auditService: MockAuditSvc())
        let step = ActionStep(toolID: ToolID("exec.test"), arguments: ToolArguments(), description: "Test", explanation: "")
        let result = try await executor.execute(step, session: AgentSessionID())
        XCTAssertTrue(result.isSuccess)
    }

    func testExecuteUnknownTool() async throws {
        let registry = ToolRegistry()
        let executor = ActionExecutorImpl(toolRegistry: registry, authGate: MockAuthGate(), auditService: MockAuditSvc())
        let step = ActionStep(toolID: ToolID("unknown"), arguments: ToolArguments(), description: "Unknown", explanation: "")
        let result = try await executor.execute(step, session: AgentSessionID())
        XCTAssertTrue(result.isFailure)
        if case .failure(let f) = result {
            XCTAssertEqual(f.source, .toolInternal)
        }
    }

    func testExecuteAuthorizationRejected() async throws {
        let registry = ToolRegistry()
        try registry.register(MockToolForExecutor())
        let authGate = MockAuthGate()
        authGate.decision = .rejected(decidedBy: UserID("test"), at: ISO8601Timestamp(), reason: "No")
        let executor = ActionExecutorImpl(toolRegistry: registry, authGate: authGate, auditService: MockAuditSvc())
        let step = ActionStep(toolID: ToolID("exec.test"), arguments: ToolArguments(), description: "Test", explanation: "")
        let result = try await executor.execute(step, session: AgentSessionID())
        XCTAssertTrue(result.isFailure)
        if case .failure(let f) = result {
            XCTAssertEqual(f.source, .authorizationRejected)
        }
    }

    func testExecuteToolFailure() async throws {
        let registry = ToolRegistry()
        let tool = MockToolForExecutor()
        tool.shouldFail = true
        try registry.register(tool)
        let executor = ActionExecutorImpl(toolRegistry: registry, authGate: MockAuthGate(), auditService: MockAuditSvc())
        let step = ActionStep(toolID: ToolID("exec.test"), arguments: ToolArguments(), description: "Test", explanation: "")
        let result = try await executor.execute(step, session: AgentSessionID())
        XCTAssertTrue(result.isFailure)
        if case .failure(let f) = result {
            XCTAssertEqual(f.source, .underlyingError)
        }
    }

    // H14: Audit recorded on every execution
    func testH14AuditRecorded() async throws {
        let registry = ToolRegistry()
        try registry.register(MockToolForExecutor())
        let auditSvc = MockAuditSvc()
        let executor = ActionExecutorImpl(toolRegistry: registry, authGate: MockAuthGate(), auditService: auditSvc)
        let step = ActionStep(toolID: ToolID("exec.test"), arguments: ToolArguments(), description: "Test", explanation: "")
        _ = try await executor.execute(step, session: AgentSessionID())
        XCTAssertEqual(auditSvc.recorded.count, 1)
    }
}
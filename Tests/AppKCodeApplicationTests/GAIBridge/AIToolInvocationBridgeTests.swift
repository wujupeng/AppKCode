import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain
@testable import AppKCodeApplication

// MARK: - Test Stubs for P3

private struct StubAgentTool: AgentTool {
    let schema: ToolSchema
    func validate(arguments: ToolArguments) -> ValidationResult { .valid }
    func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput {
        return ToolOutput(text: "ok")
    }
}

private func makeToolRegistry(with toolID: ToolID = ToolID("test.tool")) -> ToolRegistry {
    let registry = ToolRegistry()
    let schema = ToolSchema(
        id: toolID,
        category: .fileRead,
        permission: .readOnly,
        parameters: [],
        returnType: .string,
        description: "Test tool",
        version: "1.0"
    )
    try? registry.register(StubAgentTool(schema: schema))
    return registry
}

private struct StubActionExecutor_Success: ActionExecutor {
    func execute(_ step: ActionStep, session: AgentSessionID) async throws -> ActionResult {
        return .success(ActionResultSuccess(
            output: ToolOutput(text: "ok"),
            evidenceID: EvidenceRecordID(),
            durationSeconds: 0.0
        ))
    }
}

private struct StubActionExecutor_AuthDenied: ActionExecutor {
    func execute(_ step: ActionStep, session: AgentSessionID) async throws -> ActionResult {
        return .failure(ActionResultFailure(
            code: 403,
            message: "Authorization denied",
            source: .authorizationRejected
        ))
    }
}

private struct StubActionExecutor_Failure: ActionExecutor {
    func execute(_ step: ActionStep, session: AgentSessionID) async throws -> ActionResult {
        return .failure(ActionResultFailure(
            code: 500,
            message: "Internal error",
            source: .toolInternal
        ))
    }
}

private final class StubAIAuditBridge: AIAuditBridge, @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [AIAuditEvent] = []

    var events: [AIAuditEvent] {
        lock.lock()
        defer { lock.unlock() }
        return _events
    }

    func record(_ event: AIAuditEvent) async throws {
        lock.lock()
        _events.append(event)
        lock.unlock()
    }
}

// MARK: - AIToolInvocationBridge Tests (M11-P3-TASK-003)

final class AIToolInvocationBridgeTests: XCTestCase {

    // MARK: - AIToolCallRequest Tests

    func testAIToolCallRequest_construction() {
        let request = AIToolCallRequest(
            toolID: ToolID("test.tool"),
            arguments: ToolArguments(values: ["key": .string("value")]),
            source: .gaiRuntime,
            sessionID: AgentSessionID()
        )

        XCTAssertEqual(request.toolID, ToolID("test.tool"))
        XCTAssertEqual(request.source, .gaiRuntime)
    }

    func testAIToolCallRequest_equatable() {
        let sessionID = AgentSessionID()
        let req1 = AIToolCallRequest(
            toolID: ToolID("test"),
            arguments: ToolArguments(values: [:]),
            source: .gaiRuntime,
            sessionID: sessionID
        )
        let req2 = AIToolCallRequest(
            toolID: ToolID("test"),
            arguments: ToolArguments(values: [:]),
            source: .gaiRuntime,
            sessionID: sessionID
        )

        XCTAssertEqual(req1, req2)
    }

    // MARK: - AIToolCallResult Tests

    func testAIToolCallResult_construction() {
        let result = AIToolCallResult(
            toolOutput: ToolOutput(text: "output"),
            auditRecordID: AuditRecordID(),
            authorizationDecision: .allowed(decidedBy: UserID("system"), at: ISO8601Timestamp(), sha256: "test")
        )

        XCTAssertEqual(result.toolOutput.text, "output")
        if case .allowed = result.authorizationDecision {
            // Expected
        } else {
            XCTFail("Expected .allowed")
        }
    }

    // MARK: - AIToolError Tests

    func testAIToolError_unknownTool() {
        let error = AIToolError.unknownTool(toolID: ToolID("unknown"))
        if case .unknownTool(let toolID) = error {
            XCTAssertEqual(toolID, ToolID("unknown"))
        } else {
            XCTFail("Wrong error case")
        }
    }

    func testAIToolError_authorizationDenied() {
        let sessionID = AgentSessionID()
        let error = AIToolError.authorizationDenied(toolID: ToolID("test"), sessionID: sessionID)
        if case .authorizationDenied(let toolID, _) = error {
            XCTAssertEqual(toolID, ToolID("test"))
        } else {
            XCTFail("Wrong error case")
        }
    }

    func testAIToolError_equatable() {
        let error1 = AIToolError.unknownTool(toolID: ToolID("test"))
        let error2 = AIToolError.unknownTool(toolID: ToolID("test"))
        XCTAssertEqual(error1, error2)
    }

    // MARK: - invoke Tests — Known Tool

    func testInvoke_knownTool_returnsSuccess() async throws {
        let registry = makeToolRegistry()
        let executor = StubActionExecutor_Success()
        let bridge = AIToolInvocationBridgeImpl(
            toolRegistry: registry,
            actionExecutor: executor
        )

        let request = AIToolCallRequest(
            toolID: ToolID("test.tool"),
            arguments: ToolArguments(values: [:]),
            source: .gaiRuntime,
            sessionID: AgentSessionID()
        )

        let result = try await bridge.invoke(request)

        XCTAssertEqual(result.toolOutput.text, "ok")
        if case .allowed = result.authorizationDecision {
            // Expected
        } else {
            XCTFail("Expected .allowed")
        }
    }

    // MARK: - invoke Tests — Unknown Tool

    func testInvoke_unknownTool_throwsError() async throws {
        let registry = ToolRegistry()
        let executor = StubActionExecutor_Success()
        let bridge = AIToolInvocationBridgeImpl(
            toolRegistry: registry,
            actionExecutor: executor
        )

        let request = AIToolCallRequest(
            toolID: ToolID("nonexistent.tool"),
            arguments: ToolArguments(values: [:]),
            source: .gaiRuntime,
            sessionID: AgentSessionID()
        )

        do {
            _ = try await bridge.invoke(request)
            XCTFail("Should throw unknownTool")
        } catch let error as AIToolError {
            if case .unknownTool(let toolID) = error {
                XCTAssertEqual(toolID, ToolID("nonexistent.tool"))
            } else {
                XCTFail("Wrong error: \(error)")
            }
        }
    }

    // MARK: - invoke Tests — Authorization Denied

    func testInvoke_authorizationDenied_throwsError() async throws {
        let registry = makeToolRegistry()
        let executor = StubActionExecutor_AuthDenied()
        let bridge = AIToolInvocationBridgeImpl(
            toolRegistry: registry,
            actionExecutor: executor
        )

        let request = AIToolCallRequest(
            toolID: ToolID("test.tool"),
            arguments: ToolArguments(values: [:]),
            source: .gaiRuntime,
            sessionID: AgentSessionID()
        )

        do {
            _ = try await bridge.invoke(request)
            XCTFail("Should throw authorizationDenied")
        } catch let error as AIToolError {
            if case .authorizationDenied = error {
                // Expected
            } else {
                XCTFail("Wrong error: \(error)")
            }
        }
    }

    // MARK: - invoke Tests — Execution Failure

    func testInvoke_executionFailure_returnsFailureResult() async throws {
        let registry = makeToolRegistry()
        let executor = StubActionExecutor_Failure()
        let bridge = AIToolInvocationBridgeImpl(
            toolRegistry: registry,
            actionExecutor: executor
        )

        let request = AIToolCallRequest(
            toolID: ToolID("test.tool"),
            arguments: ToolArguments(values: [:]),
            source: .gaiRuntime,
            sessionID: AgentSessionID()
        )

        let result = try await bridge.invoke(request)

        XCTAssertTrue(result.toolOutput.text?.contains("Error") == true)
        if case .rejected = result.authorizationDecision {
            // Expected
        } else {
            XCTFail("Expected .rejected")
        }
    }

    // MARK: - invoke Tests — Audit Bridge

    func testInvoke_withAuditBridge_recordsEvents() async throws {
        let registry = makeToolRegistry()
        let executor = StubActionExecutor_Success()
        let auditBridge = StubAIAuditBridge()
        let bridge = AIToolInvocationBridgeImpl(
            toolRegistry: registry,
            actionExecutor: executor,
            auditBridge: auditBridge
        )

        let request = AIToolCallRequest(
            toolID: ToolID("test.tool"),
            arguments: ToolArguments(values: [:]),
            source: .gaiRuntime,
            sessionID: AgentSessionID()
        )

        _ = try await bridge.invoke(request)

        let events = auditBridge.events
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].kind, .aiToolCallRequested)
        XCTAssertEqual(events[1].kind, .aiToolCallExecuted)
    }

    func testInvoke_unknownTool_withAuditBridge_recordsDenied() async throws {
        let registry = ToolRegistry()
        let executor = StubActionExecutor_Success()
        let auditBridge = StubAIAuditBridge()
        let bridge = AIToolInvocationBridgeImpl(
            toolRegistry: registry,
            actionExecutor: executor,
            auditBridge: auditBridge
        )

        let request = AIToolCallRequest(
            toolID: ToolID("nonexistent"),
            arguments: ToolArguments(values: [:]),
            source: .gaiRuntime,
            sessionID: AgentSessionID()
        )

        do {
            _ = try await bridge.invoke(request)
        } catch {
            // Expected
        }

        let events = auditBridge.events
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].kind, .aiToolCallRequested)
        XCTAssertEqual(events[1].kind, .aiToolCallDenied)
    }

    // MARK: - AICapabilityAuthorizationBridge Protocol Tests

    func testAICapabilityRequest_construction() {
        let request = AICapabilityRequest(
            capabilityID: CapabilityID("test.capability"),
            extensionID: ExtensionID("test.extension"),
            input: .string("test"),
            source: .codeArtsAgent,
            sessionID: AgentSessionID()
        )

        XCTAssertEqual(request.source, .codeArtsAgent)
        XCTAssertEqual(request.capabilityID, CapabilityID("test.capability"))
    }

    func testAICapabilityError_equatable() {
        let capID = CapabilityID("test")
        let error1 = AICapabilityError.noContract(capabilityID: capID)
        let error2 = AICapabilityError.noContract(capabilityID: capID)
        XCTAssertEqual(error1, error2)
    }
}
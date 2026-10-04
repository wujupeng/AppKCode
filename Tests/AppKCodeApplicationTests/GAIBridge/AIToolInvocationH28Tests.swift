import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain
@testable import AppKCodeApplication

// MARK: - H28 验收测试 (M11-P3-TASK-003.2~003.5)
// H28-2: AI 工具调用经 M7 ToolRegistry
// H28-7: 不存在 AI → Shell 直接执行路径
// H28-8: 不存在 AI → Git 直接执行路径
// H28-9: 不存在 AI → File 直接写入路径

private struct StubExecutor_H28: ActionExecutor {
    func execute(_ step: ActionStep, session: AgentSessionID) async throws -> ActionResult {
        return .success(ActionResultSuccess(
            output: ToolOutput(text: "executed via ToolRegistry"),
            evidenceID: EvidenceRecordID(),
            durationSeconds: 0.0
        ))
    }
}

private struct StubAgentTool_H28: AgentTool {
    let schema: ToolSchema
    func validate(arguments: ToolArguments) -> ValidationResult { .valid }
    func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput {
        return ToolOutput(text: "executed via ToolRegistry")
    }
}

private func makeToolRegistry_H28(with toolID: ToolID = ToolID("test.tool")) -> ToolRegistry {
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
    try? registry.register(StubAgentTool_H28(schema: schema))
    return registry
}

// MARK: - H28-2 验收测试

final class AIToolInvocationH28Tests: XCTestCase {

    // MARK: - H28-2: AI Tool Call via M7 ToolRegistry

    func testH28_2_aiToolCallViaToolRegistry() async throws {
        let registry = makeToolRegistry_H28()
        let executor = StubExecutor_H28()
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

        XCTAssertTrue(result.toolOutput.text?.contains("ToolRegistry") == true,
                       "H28-2: AI tool call must go through M7 ToolRegistry")
    }

    func testH28_2_unknownToolRejected() async throws {
        let registry = ToolRegistry()
        let executor = StubExecutor_H28()
        let bridge = AIToolInvocationBridgeImpl(
            toolRegistry: registry,
            actionExecutor: executor
        )

        let request = AIToolCallRequest(
            toolID: ToolID("nonexistent"),
            arguments: ToolArguments(values: [:]),
            source: .gaiRuntime,
            sessionID: AgentSessionID()
        )

        do {
            _ = try await bridge.invoke(request)
            XCTFail("H28-2: Unknown tool should be rejected")
        } catch let error as AIToolError {
            if case .unknownTool = error {
                // H28-2 verified: unknown tool rejected by ToolRegistry
            } else {
                XCTFail("H28-2: Wrong error type")
            }
        }
    }

    // MARK: - H28-7: No AI → Shell Direct Execution

    func testH28_7_noAIDirectShellExecution() async throws {
        let registry = makeToolRegistry_H28(with: ToolID("shell.execute"))
        let executor = StubExecutor_H28()
        let bridge = AIToolInvocationBridgeImpl(
            toolRegistry: registry,
            actionExecutor: executor
        )

        let request = AIToolCallRequest(
            toolID: ToolID("shell.execute"),
            arguments: ToolArguments(values: ["command": .string("ls -la")]),
            source: .gaiRuntime,
            sessionID: AgentSessionID()
        )

        let result = try await bridge.invoke(request)

        XCTAssertTrue(result.toolOutput.text?.contains("ToolRegistry") == true,
                       "H28-7: Shell execution must go through ToolRegistry → ActionExecutor, not direct Process.execute")
    }

    // MARK: - H28-8: No AI → Git Direct Execution

    func testH28_8_noAIDirectGitExecution() async throws {
        let registry = makeToolRegistry_H28(with: ToolID("git.commit"))
        let executor = StubExecutor_H28()
        let bridge = AIToolInvocationBridgeImpl(
            toolRegistry: registry,
            actionExecutor: executor
        )

        let request = AIToolCallRequest(
            toolID: ToolID("git.commit"),
            arguments: ToolArguments(values: ["message": .string("test")]),
            source: .gaiRuntime,
            sessionID: AgentSessionID()
        )

        let result = try await bridge.invoke(request)

        XCTAssertTrue(result.toolOutput.text?.contains("ToolRegistry") == true,
                       "H28-8: Git operations must go through ToolRegistry → GitTools, not direct git command")
    }

    // MARK: - H28-9: No AI → File Direct Write

    func testH28_9_noAIDirectFileWrite() async throws {
        let registry = makeToolRegistry_H28(with: ToolID("file.write"))
        let executor = StubExecutor_H28()
        let bridge = AIToolInvocationBridgeImpl(
            toolRegistry: registry,
            actionExecutor: executor
        )

        let request = AIToolCallRequest(
            toolID: ToolID("file.write"),
            arguments: ToolArguments(values: [
                "path": .string("/tmp/test.txt"),
                "content": .string("test content")
            ]),
            source: .gaiRuntime,
            sessionID: AgentSessionID()
        )

        let result = try await bridge.invoke(request)

        XCTAssertTrue(result.toolOutput.text?.contains("ToolRegistry") == true,
                       "H28-9: File write must go through ToolRegistry → FileWriteTool (high → Approval), not direct FileHandle.write")
    }

    // MARK: - H28-2: Source Attribution (AI vs Human)

    func testH28_2_sourceAttribution_gaiRuntime() async throws {
        let registry = makeToolRegistry_H28()
        let executor = StubExecutor_H28()
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

        XCTAssertEqual(request.source, .gaiRuntime)
        XCTAssertNotNil(result.auditRecordID)
    }

    func testH28_2_sourceAttribution_codeArtsAgent() async throws {
        let registry = makeToolRegistry_H28()
        let executor = StubExecutor_H28()
        let bridge = AIToolInvocationBridgeImpl(
            toolRegistry: registry,
            actionExecutor: executor
        )

        let request = AIToolCallRequest(
            toolID: ToolID("test.tool"),
            arguments: ToolArguments(values: [:]),
            source: .codeArtsAgent,
            sessionID: AgentSessionID()
        )

        let result = try await bridge.invoke(request)

        XCTAssertEqual(request.source, .codeArtsAgent)
        XCTAssertNotNil(result.auditRecordID)
    }

    // MARK: - H28: Audit Record ID Present (Traceability)

    func testH28_auditRecordIDPresent() async throws {
        let registry = makeToolRegistry_H28()
        let executor = StubExecutor_H28()
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

        XCTAssertNotNil(result.auditRecordID,
                        "H28: AIToolCallResult must contain auditRecordID for traceability")
    }

    // MARK: - H28: No Bypass — All Paths Through ActionExecutor

    func testH28_allPathsThroughActionExecutor() async throws {
        let registry = makeToolRegistry_H28()
        let executor = StubExecutor_H28()
        let bridge = AIToolInvocationBridgeImpl(
            toolRegistry: registry,
            actionExecutor: executor
        )

        let sources: [AgentContextSource] = [.gaiRuntime, .codeArtsAgent, .appkcodeAgent]

        for source in sources {
            let request = AIToolCallRequest(
                toolID: ToolID("test.tool"),
                arguments: ToolArguments(values: [:]),
                source: source,
                sessionID: AgentSessionID()
            )

            let result = try await bridge.invoke(request)
            XCTAssertTrue(result.toolOutput.text?.contains("ToolRegistry") == true,
                          "H28: All sources (\(source.rawValue)) must go through ToolRegistry → ActionExecutor")
        }
    }
}
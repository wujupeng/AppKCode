import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain
@testable import AppKCodeApplication

// MARK: - M11-P7-TASK-002: G-AI 端到端集成测试
// 对应需求: m11_tasks.md §9 TASK-002
// 对应硬约束: H28-1 ~ H28-10

// MARK: - E2E Test Stubs

private final class E2EGAIBridge: GAIRuntimeBridge, @unchecked Sendable {
    private let lock = NSLock()
    private var _states: [AgentSessionID: GAIWorkflowState] = [:]
    private var _advanceCount = 0

    var advanceCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _advanceCount
    }

    func submitTask(_ task: GAIWorkflowTask) async throws -> GAIWorkflowState {
        let sessionID = AgentSessionID()
        let state = GAIWorkflowState(
            sessionID: sessionID,
            taskID: task.id,
            currentPhase: task.phase,
            status: .inProgress
        )
        lock.lock()
        _states[sessionID] = state
        lock.unlock()
        return state
    }

    func advance(phase: GAIWorkflowPhase, session: AgentSessionID) async throws -> GAIWorkflowState {
        lock.lock()
        _advanceCount += 1
        guard var state = _states[session] else {
            lock.unlock()
            throw GAIError.sessionNotFound(session: session)
        }
        state.currentPhase = phase
        state.stepsTaken += 1
        if phase == .gate {
            state.status = .completed
        }
        _states[session] = state
        lock.unlock()
        return state
    }

    func currentState(session: AgentSessionID) async throws -> GAIWorkflowState {
        lock.lock(); defer { lock.unlock() }
        guard let state = _states[session] else {
            throw GAIError.sessionNotFound(session: session)
        }
        return state
    }

    func cancel(session: AgentSessionID) async throws {
        lock.lock()
        if var state = _states[session] {
            state.status = .cancelled
            _states[session] = state
        }
        lock.unlock()
    }
}

private struct E2EContextBridge: AgentContextBridge {
    let contextItems: [ContextItem]

    func gatherContext(_ request: AgentContextRequest) async throws -> [ContextItem] {
        return contextItems
    }
}

private final class E2EToolBridge: AIToolInvocationBridge, @unchecked Sendable {
    private let lock = NSLock()
    private var _invokeCount = 0

    var invokeCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _invokeCount
    }

    func invoke(_ request: AIToolCallRequest) async throws -> AIToolCallResult {
        lock.lock(); _invokeCount += 1; lock.unlock()
        return AIToolCallResult(
            toolOutput: ToolOutput(text: "E2E tool result for \(request.toolID.rawValue)"),
            auditRecordID: AuditRecordID(),
            authorizationDecision: .allowed(
                decidedBy: UserID("e2e-test"),
                at: ISO8601Timestamp(),
                sha256: "e2e-sha256"
            )
        )
    }
}

private final class E2EAuthBridge: AICapabilityAuthorizationBridge, @unchecked Sendable {
    let allowCapability: Bool

    init(allowCapability: Bool = true) {
        self.allowCapability = allowCapability
    }

    func authorize(_ request: AICapabilityRequest) async throws -> AuthorizationDecision {
        if allowCapability {
            return .allowed(
                decidedBy: UserID("e2e-auth"),
                at: ISO8601Timestamp(),
                sha256: "e2e-auth-sha"
            )
        } else {
            return .rejected(
                decidedBy: UserID("e2e-auth"),
                at: ISO8601Timestamp(),
                reason: "E2E test denial"
            )
        }
    }
}

private final class E2EAuditBridge: AIAuditBridge, @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [AIAuditEvent] = []

    var events: [AIAuditEvent] {
        lock.lock(); defer { lock.unlock() }
        return _events
    }

    var eventKinds: [AIAuditEventKind] {
        events.map { $0.kind }
    }

    func record(_ event: AIAuditEvent) async throws {
        lock.lock()
        _events.append(event)
        lock.unlock()
    }
}

private final class E2ECapabilityAppService: CapabilityAppService, @unchecked Sendable {
    func listCapabilities() async -> [CapabilityDescriptor] { return [] }
    func listCapabilities(byCategory: CapabilityCategory) async -> [CapabilityDescriptor] { return [] }
    func listCapabilities(forExtension id: ExtensionID) async -> [CapabilityDescriptor] { return [] }

    func invokeCapability(
        _ id: CapabilityID,
        extensionID: ExtensionID,
        input: AnyCodableValue,
        sessionID: AgentSessionID
    ) async throws -> CapabilityInvocationResult {
        return .success(output: .null, evidence: [])
    }

    func runContractTests(_ contractID: CapabilityContractID) async throws -> ContractTestResult {
        return ContractTestResult(contractID: contractID, passed: true, failures: [])
    }
}

// MARK: - Helpers

private func makeE2EOrchestrator(
    allowCapability: Bool = true,
    contextItems: [ContextItem] = []
) -> (GAIIntegrationOrchestrator, E2EGAIBridge, E2EContextBridge, E2EToolBridge, E2EAuthBridge, E2EAuditBridge) {
    let gaiBridge = E2EGAIBridge()
    let contextBridge = E2EContextBridge(contextItems: contextItems)
    let toolBridge = E2EToolBridge()
    let authBridge = E2EAuthBridge(allowCapability: allowCapability)
    let auditBridge = E2EAuditBridge()
    let capService = E2ECapabilityAppService()

    let codeArtsOrchestrator = CodeArtsAgentOrchestrator(
        capabilityAppService: capService,
        contextBridge: contextBridge,
        auditBridge: auditBridge
    )

    let orchestrator = GAIIntegrationOrchestrator(
        gaiBridge: gaiBridge,
        contextBridge: contextBridge,
        toolBridge: toolBridge,
        authBridge: authBridge,
        auditBridge: auditBridge,
        codeArtsOrchestrator: codeArtsOrchestrator
    )

    return (orchestrator, gaiBridge, contextBridge, toolBridge, authBridge, auditBridge)
}

private func makeE2ERequest(
    phase: GAIWorkflowPhase = .spec,
    toolCalls: [AIToolCallRequest] = [],
    capabilityRequest: AICapabilityRequest? = nil
) -> GAIIntegrationRequest {
    let task = GAIWorkflowTask(
        phase: phase,
        userRequest: "E2E test request",
        contextRequest: "E2E context",
        maxSteps: 10
    )

    return GAIIntegrationRequest(
        task: task,
        contextRequest: AgentContextRequest(
            source: .gaiRuntime,
            projectRoot: URL(fileURLWithPath: "/tmp/e2e-project")
        ),
        toolCalls: toolCalls,
        capabilityRequest: capabilityRequest
    )
}

// MARK: - EndToEndGAIIntegrationTests

final class EndToEndGAIIntegrationTests: XCTestCase {

    // MARK: - TASK-002.1: G-AI 全链路集成测试

    func testGAIFullChain_specToGate() async throws {
        let (orchestrator, gaiBridge, _, _, _, auditBridge) = makeE2EOrchestrator()
        let request = makeE2ERequest()

        let result = try await orchestrator.runGAIIntegration(request)

        XCTAssertEqual(result.status, .completed)
        XCTAssertNotNil(result.workflowState)
        XCTAssertEqual(gaiBridge.advanceCount, GAIWorkflowPhase.allCases.count)
        XCTAssertTrue(auditBridge.events.contains { $0.kind == .gaiWorkflowStarted })
        XCTAssertTrue(auditBridge.events.contains { $0.kind == .gaiWorkflowCompleted })
    }

    func testGAIInferencePath() async throws {
        let (orchestrator, _, _, _, _, auditBridge) = makeE2EOrchestrator()
        let request = makeE2ERequest(phase: .spec)

        let result = try await orchestrator.runGAIIntegration(request)

        XCTAssertEqual(result.status, .completed)
        let startedEvents = auditBridge.events.filter { $0.kind == .gaiWorkflowStarted }
        XCTAssertEqual(startedEvents.count, 1)
    }

    func testGAIWorkflowAdvance() async throws {
        let (orchestrator, gaiBridge, _, _, _, auditBridge) = makeE2EOrchestrator()
        let request = makeE2ERequest()

        let result = try await orchestrator.runGAIIntegration(request)

        XCTAssertNotNil(result.workflowState)
        let phaseStartedEvents = auditBridge.events.filter { $0.kind == .gaiWorkflowPhaseStarted }
        let phaseCompletedEvents = auditBridge.events.filter { $0.kind == .gaiWorkflowPhaseCompleted }
        XCTAssertEqual(phaseStartedEvents.count, GAIWorkflowPhase.allCases.count)
        XCTAssertGreaterThanOrEqual(phaseCompletedEvents.count, 1)
    }

    func testGAIHighRiskApproval() async throws {
        let (orchestrator, _, _, _, _, auditBridge) = makeE2EOrchestrator(allowCapability: false)

        let capRequest = AICapabilityRequest(
            capabilityID: CapabilityID("e2e.highrisk"),
            extensionID: ExtensionID("e2e.ext"),
            input: .null,
            source: .gaiRuntime,
            sessionID: AgentSessionID()
        )

        let request = makeE2ERequest(phase: .implementation, capabilityRequest: capRequest)

        do {
            _ = try await orchestrator.runGAIIntegration(request)
            XCTFail("Should throw authorizationDenied")
        } catch let error as GAIIntegrationError {
            if case .authorizationDenied = error {
                let deniedEvents = auditBridge.events.filter { $0.kind == .gaiWorkflowFailed }
                XCTAssertTrue(deniedEvents.contains { $0.detail.contains("denied") })
            } else {
                XCTFail("Expected .authorizationDenied, got \(error)")
            }
        }
    }

    // MARK: - TASK-002.2: E2E with tool calls

    func testGAIWithToolCalls() async throws {
        let (orchestrator, _, _, toolBridge, _, auditBridge) = makeE2EOrchestrator()

        let toolCalls = [
            AIToolCallRequest(
                toolID: ToolID("file.read"),
                arguments: ToolArguments(values: ["path": .string("/tmp/test.swift")]),
                source: .gaiRuntime,
                sessionID: AgentSessionID()
            ),
            AIToolCallRequest(
                toolID: ToolID("build.run"),
                arguments: ToolArguments(values: [:]),
                source: .gaiRuntime,
                sessionID: AgentSessionID()
            )
        ]

        let request = makeE2ERequest(toolCalls: toolCalls)
        let result = try await orchestrator.runGAIIntegration(request)

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.toolCallResults.count, 2)
        XCTAssertEqual(toolBridge.invokeCount, 2)
        XCTAssertEqual(result.auditRecordIDs.count, 2)

        let toolRequestedEvents = auditBridge.events.filter { $0.kind == .aiToolCallRequested }
        let toolCompletedEvents = auditBridge.events.filter { $0.kind == .aiToolCallCompleted }
        XCTAssertEqual(toolRequestedEvents.count, 2)
        XCTAssertEqual(toolCompletedEvents.count, 2)
    }

    // MARK: - TASK-002.3: E2E with context

    func testGAIWithContextGathering() async throws {
        let contextItems = [
            ContextItem(source: .currentFile, content: "func test() {}", metadata: ContextMetadata()),
            ContextItem(source: .selectedText, content: "test()", metadata: ContextMetadata())
        ]

        let (orchestrator, _, _, _, _, auditBridge) = makeE2EOrchestrator(contextItems: contextItems)
        let request = makeE2ERequest()

        let result = try await orchestrator.runGAIIntegration(request)

        XCTAssertEqual(result.status, .completed)
        let completedEvent = auditBridge.events.first { $0.kind == .gaiWorkflowCompleted }
        XCTAssertNotNil(completedEvent)
        XCTAssertTrue(completedEvent!.detail.contains("2 context items"))
    }

    // MARK: - TASK-002.4: E2E error handling

    func testGAIContextBridgeFailure() async throws {
        struct FailingContextBridge: AgentContextBridge {
            func gatherContext(_ request: AgentContextRequest) async throws -> [ContextItem] {
                throw AgentContextError.aggregationFailed(reason: "E2E failure")
            }
        }

        let gaiBridge = E2EGAIBridge()
        let contextBridge = FailingContextBridge()
        let toolBridge = E2EToolBridge()
        let authBridge = E2EAuthBridge()
        let auditBridge = E2EAuditBridge()
        let capService = E2ECapabilityAppService()

        let codeArtsOrchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge
        )

        let orchestrator = GAIIntegrationOrchestrator(
            gaiBridge: gaiBridge,
            contextBridge: contextBridge,
            toolBridge: toolBridge,
            authBridge: authBridge,
            auditBridge: auditBridge,
            codeArtsOrchestrator: codeArtsOrchestrator
        )

        let request = makeE2ERequest()

        do {
            _ = try await orchestrator.runGAIIntegration(request)
            XCTFail("Should throw contextBridgeFailed")
        } catch let error as GAIIntegrationError {
            if case .contextBridgeFailed = error {
                // expected
            } else {
                XCTFail("Expected .contextBridgeFailed, got \(error)")
            }
        }
    }

    func testGAIToolBridgeFailure() async throws {
        struct FailingToolBridge: AIToolInvocationBridge {
            func invoke(_ request: AIToolCallRequest) async throws -> AIToolCallResult {
                throw AIToolError.executionFailed(toolID: request.toolID, reason: "E2E failure")
            }
        }

        let gaiBridge = E2EGAIBridge()
        let contextBridge = E2EContextBridge(contextItems: [])
        let toolBridge = FailingToolBridge()
        let authBridge = E2EAuthBridge()
        let auditBridge = E2EAuditBridge()
        let capService = E2ECapabilityAppService()

        let codeArtsOrchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge
        )

        let orchestrator = GAIIntegrationOrchestrator(
            gaiBridge: gaiBridge,
            contextBridge: contextBridge,
            toolBridge: toolBridge,
            authBridge: authBridge,
            auditBridge: auditBridge,
            codeArtsOrchestrator: codeArtsOrchestrator
        )

        let toolCalls = [
            AIToolCallRequest(
                toolID: ToolID("failing.tool"),
                arguments: ToolArguments(values: [:]),
                source: .gaiRuntime,
                sessionID: AgentSessionID()
            )
        ]

        let request = makeE2ERequest(toolCalls: toolCalls)

        do {
            _ = try await orchestrator.runGAIIntegration(request)
            XCTFail("Should throw toolBridgeFailed")
        } catch let error as GAIIntegrationError {
            if case .toolBridgeFailed = error {
                // expected
            } else {
                XCTFail("Expected .toolBridgeFailed, got \(error)")
            }
        }
    }

    // MARK: - TASK-002.5: Audit chain verification

    func testGAIAuditChainComplete() async throws {
        let (orchestrator, _, _, _, _, auditBridge) = makeE2EOrchestrator()
        let request = makeE2ERequest()

        _ = try await orchestrator.runGAIIntegration(request)

        let kinds = auditBridge.eventKinds
        XCTAssertTrue(kinds.contains(.gaiWorkflowStarted), "Missing gaiWorkflowStarted")
        XCTAssertTrue(kinds.contains(.gaiWorkflowCompleted), "Missing gaiWorkflowCompleted")
        XCTAssertTrue(kinds.contains(.gaiWorkflowPhaseStarted), "Missing gaiWorkflowPhaseStarted")

        let allEventsHaveSessionID = auditBridge.events.allSatisfy { event in
            !event.sessionID.rawValue.isEmpty
        }
        XCTAssertTrue(allEventsHaveSessionID, "Some events missing sessionID")
    }
}
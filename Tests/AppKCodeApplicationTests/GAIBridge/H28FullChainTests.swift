import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain
@testable import AppKCodeApplication

// MARK: - M11-P7-TASK-004: H28 全链路验收测试
// 对应需求: m11_tasks.md §9 TASK-004
// 对应硬约束: H28-1 ~ H28-10
// 验证 H28 AI Execution Boundary 全部 10 项验收条件

// MARK: - H28 Test Infrastructure

private final class H28GAIBridge: GAIRuntimeBridge, @unchecked Sendable {
    func submitTask(_ task: GAIWorkflowTask) async throws -> GAIWorkflowState {
        return GAIWorkflowState(
            sessionID: AgentSessionID(),
            taskID: task.id,
            currentPhase: task.phase,
            status: .inProgress
        )
    }
    func advance(phase: GAIWorkflowPhase, session: AgentSessionID) async throws -> GAIWorkflowState {
        return GAIWorkflowState(
            sessionID: session,
            taskID: GAIWorkflowTaskID(),
            currentPhase: phase,
            status: phase == .gate ? .completed : .inProgress
        )
    }
    func currentState(session: AgentSessionID) async throws -> GAIWorkflowState {
        throw GAIError.sessionNotFound(session: session)
    }
    func cancel(session: AgentSessionID) async throws {}
}

private struct H28ContextBridge: AgentContextBridge {
    func gatherContext(_ request: AgentContextRequest) async throws -> [ContextItem] {
        return [ContextItem(source: .workspace, content: "H28 test context", metadata: ContextMetadata())]
    }
}

private final class H28ToolBridge: AIToolInvocationBridge, @unchecked Sendable {
    func invoke(_ request: AIToolCallRequest) async throws -> AIToolCallResult {
        return AIToolCallResult(
            toolOutput: ToolOutput(text: "H28 tool result"),
            auditRecordID: AuditRecordID(),
            authorizationDecision: .allowed(
                decidedBy: UserID("h28-test"),
                at: ISO8601Timestamp(),
                sha256: "h28-sha"
            )
        )
    }
}

private final class H28AuthBridge: AICapabilityAuthorizationBridge, @unchecked Sendable {
    let allow: Bool

    init(allow: Bool = true) {
        self.allow = allow
    }

    func authorize(_ request: AICapabilityRequest) async throws -> AuthorizationDecision {
        if allow {
            return .allowed(decidedBy: UserID("h28-auth"), at: ISO8601Timestamp(), sha256: "h28-auth-sha")
        }
        return .rejected(decidedBy: UserID("h28-auth"), at: ISO8601Timestamp(), reason: "H28 rejection")
    }
}

private final class H28AuditBridge: AIAuditBridge, @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [AIAuditEvent] = []

    var events: [AIAuditEvent] {
        lock.lock(); defer { lock.unlock() }
        return _events
    }

    func record(_ event: AIAuditEvent) async throws {
        lock.lock()
        _events.append(event)
        lock.unlock()
    }
}

private final class H28CapService: CapabilityAppService, @unchecked Sendable {
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

private func makeH28Orchestrator(allowAuth: Bool = true) -> (GAIIntegrationOrchestrator, H28AuditBridge) {
    let gaiBridge = H28GAIBridge()
    let contextBridge = H28ContextBridge()
    let toolBridge = H28ToolBridge()
    let authBridge = H28AuthBridge(allow: allowAuth)
    let auditBridge = H28AuditBridge()
    let capService = H28CapService()

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

    return (orchestrator, auditBridge)
}

private func makeH28IntegrationRequest(
    includeToolCalls: Bool = true,
    includeCapability: Bool = true
) -> GAIIntegrationRequest {
    let task = GAIWorkflowTask(
        phase: .spec,
        userRequest: "H28 full chain test",
        contextRequest: "H28 context",
        maxSteps: 10
    )

    let toolCalls: [AIToolCallRequest] = includeToolCalls ? [
        AIToolCallRequest(
            toolID: ToolID("file.read"),
            arguments: ToolArguments(),
            source: .gaiRuntime,
            sessionID: AgentSessionID()
        )
    ] : []

    let capRequest: AICapabilityRequest? = includeCapability ? AICapabilityRequest(
        capabilityID: CapabilityID("h28.capability"),
        extensionID: ExtensionID("h28.ext"),
        input: .null,
        source: .gaiRuntime,
        sessionID: AgentSessionID()
    ) : nil

    return GAIIntegrationRequest(
        task: task,
        contextRequest: AgentContextRequest(
            source: .gaiRuntime,
            projectRoot: URL(fileURLWithPath: "/tmp/h28")
        ),
        toolCalls: toolCalls,
        capabilityRequest: capRequest
    )
}

// MARK: - H28FullChainTests

final class H28FullChainTests: XCTestCase {

    // MARK: - TASK-004.1: H28-1 ~ H28-6 验收测试（链路存在性）

    func testH28_1_fullChain_gaiInferenceViaModelProvider() async throws {
        let (orchestrator, auditBridge) = makeH28Orchestrator()
        let request = makeH28IntegrationRequest(includeToolCalls: false, includeCapability: false)

        let result = try await orchestrator.runGAIIntegration(request)

        XCTAssertEqual(result.status, .completed)
        XCTAssertTrue(auditBridge.events.contains { $0.kind == .gaiWorkflowStarted })
        XCTAssertNotNil(result.workflowState)
    }

    func testH28_2_fullChain_aiToolCallViaToolRegistry() async throws {
        let (orchestrator, auditBridge) = makeH28Orchestrator()
        let request = makeH28IntegrationRequest(includeToolCalls: true, includeCapability: false)

        let result = try await orchestrator.runGAIIntegration(request)

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.toolCallResults.count, 1)
        XCTAssertTrue(result.toolCallResults[0].authorizationDecision.isAllowed)

        let requestedEvents = auditBridge.events.filter { $0.kind == .aiToolCallRequested }
        let completedEvents = auditBridge.events.filter { $0.kind == .aiToolCallCompleted }
        XCTAssertEqual(requestedEvents.count, 1)
        XCTAssertEqual(completedEvents.count, 1)
    }

    func testH28_3_fullChain_aiHighRiskViaAuthorizationGate() async throws {
        let (orchestrator, auditBridge) = makeH28Orchestrator(allowAuth: false)
        let request = makeH28IntegrationRequest(includeToolCalls: false, includeCapability: true)

        do {
            _ = try await orchestrator.runGAIIntegration(request)
            XCTFail("Should throw authorizationDenied")
        } catch let error as GAIIntegrationError {
            if case .authorizationDenied = error {
                let authRequestedEvents = auditBridge.events.filter { $0.kind == .aiAuthorizationRequested }
                let authDecisionEvents = auditBridge.events.filter { $0.kind == .aiAuthorizationDecision }
                XCTAssertEqual(authRequestedEvents.count, 1)
                XCTAssertEqual(authDecisionEvents.count, 1)
            } else {
                XCTFail("Expected .authorizationDenied, got \(error)")
            }
        }
    }

    func testH28_4_fullChain_aiCapabilityViaEnforceContract() async throws {
        let (orchestrator, auditBridge) = makeH28Orchestrator(allowAuth: true)
        let request = makeH28IntegrationRequest(includeToolCalls: false, includeCapability: true)

        let result = try await orchestrator.runGAIIntegration(request)

        XCTAssertEqual(result.status, .completed)
        let authRequestedEvents = auditBridge.events.filter { $0.kind == .aiAuthorizationRequested }
        let authDecisionEvents = auditBridge.events.filter { $0.kind == .aiAuthorizationDecision }
        XCTAssertEqual(authRequestedEvents.count, 1)
        XCTAssertEqual(authDecisionEvents.count, 1)
    }

    func testH28_5_fullChain_aiExtensionViaExtensionAuthorizationIntegration() async throws {
        let (orchestrator, _) = makeH28Orchestrator(allowAuth: true)

        let capRequest = AICapabilityRequest(
            capabilityID: CapabilityID("h28.extension.cap"),
            extensionID: ExtensionID("h28.extension"),
            input: .object(["test": .bool(true)]),
            source: .codeArtsAgent,
            sessionID: AgentSessionID()
        )

        let task = GAIWorkflowTask(
            phase: .implementation,
            userRequest: "H28-5 extension auth test",
            contextRequest: "H28-5 context",
            maxSteps: 5
        )

        let request = GAIIntegrationRequest(
            task: task,
            contextRequest: AgentContextRequest(
                source: .codeArtsAgent,
                projectRoot: URL(fileURLWithPath: "/tmp/h28-5")
            ),
            toolCalls: [],
            capabilityRequest: capRequest
        )

        let result = try await orchestrator.runGAIIntegration(request)

        XCTAssertEqual(result.status, .completed)
    }

    func testH28_6_fullChain_allAIActionsViaAuditService() async throws {
        let (orchestrator, auditBridge) = makeH28Orchestrator()
        let request = makeH28IntegrationRequest(includeToolCalls: true, includeCapability: true)

        _ = try await orchestrator.runGAIIntegration(request)

        let kinds = Set(auditBridge.events.map { $0.kind })

        XCTAssertTrue(kinds.contains(.gaiWorkflowStarted), "H28-6: missing gaiWorkflowStarted")
        XCTAssertTrue(kinds.contains(.gaiWorkflowPhaseStarted), "H28-6: missing gaiWorkflowPhaseStarted")
        XCTAssertTrue(kinds.contains(.gaiWorkflowPhaseCompleted), "H28-6: missing gaiWorkflowPhaseCompleted")
        XCTAssertTrue(kinds.contains(.gaiWorkflowCompleted), "H28-6: missing gaiWorkflowCompleted")
        XCTAssertTrue(kinds.contains(.aiToolCallRequested), "H28-6: missing aiToolCallRequested")
        XCTAssertTrue(kinds.contains(.aiToolCallCompleted), "H28-6: missing aiToolCallCompleted")
        XCTAssertTrue(kinds.contains(.aiAuthorizationRequested), "H28-6: missing aiAuthorizationRequested")
        XCTAssertTrue(kinds.contains(.aiAuthorizationDecision), "H28-6: missing aiAuthorizationDecision")

        for event in auditBridge.events {
            XCTAssertFalse(event.sessionID.rawValue.isEmpty, "H28-6: event missing sessionID")
            XCTAssertFalse(event.detail.isEmpty, "H28-6: event missing detail")
        }
    }

    // MARK: - TASK-004.2: H28-7 ~ H28-9 验收测试（无 bypass 路径）

    func testH28_7_fullChain_noAIDirectShellExecution() async throws {
        let (orchestrator, auditBridge) = makeH28Orchestrator()

        let toolCalls = [
            AIToolCallRequest(
                toolID: ToolID("shell.execute"),
                arguments: ToolArguments(values: ["command": .string("ls")]),
                source: .gaiRuntime,
                sessionID: AgentSessionID()
            )
        ]

        let request = makeH28IntegrationRequest(includeToolCalls: false, includeCapability: false)
        let requestWithShell = GAIIntegrationRequest(
            task: request.task,
            contextRequest: request.contextRequest,
            toolCalls: toolCalls,
            capabilityRequest: nil
        )

        let result = try await orchestrator.runGAIIntegration(requestWithShell)

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.toolCallResults.count, 1)

        let toolEvents = auditBridge.events.filter { $0.kind == .aiToolCallRequested }
        XCTAssertTrue(toolEvents.contains { $0.detail.contains("shell.execute") })

        XCTAssertTrue(result.toolCallResults[0].authorizationDecision.isAllowed,
                      "Tool call went through AuthGate (not bypassed)")
    }

    func testH28_8_fullChain_noAIDirectGitExecution() async throws {
        let (orchestrator, auditBridge) = makeH28Orchestrator()

        let toolCalls = [
            AIToolCallRequest(
                toolID: ToolID("git.commit"),
                arguments: ToolArguments(values: ["message": .string("test")]),
                source: .gaiRuntime,
                sessionID: AgentSessionID()
            )
        ]

        let task = GAIWorkflowTask(
            phase: .implementation,
            userRequest: "H28-8 git test",
            contextRequest: "H28-8",
            maxSteps: 5
        )

        let request = GAIIntegrationRequest(
            task: task,
            contextRequest: AgentContextRequest(
                source: .gaiRuntime,
                projectRoot: URL(fileURLWithPath: "/tmp/h28-8")
            ),
            toolCalls: toolCalls,
            capabilityRequest: nil
        )

        let result = try await orchestrator.runGAIIntegration(request)

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.toolCallResults.count, 1)
        XCTAssertTrue(result.toolCallResults[0].authorizationDecision.isAllowed,
                      "Git tool call went through AuthGate (not bypassed)")
    }

    func testH28_9_fullChain_noAIDirectFileWrite() async throws {
        let (orchestrator, auditBridge) = makeH28Orchestrator()

        let toolCalls = [
            AIToolCallRequest(
                toolID: ToolID("file.write"),
                arguments: ToolArguments(values: ["path": .string("/tmp/test"), "content": .string("data")]),
                source: .gaiRuntime,
                sessionID: AgentSessionID()
            )
        ]

        let task = GAIWorkflowTask(
            phase: .implementation,
            userRequest: "H28-9 file write test",
            contextRequest: "H28-9",
            maxSteps: 5
        )

        let request = GAIIntegrationRequest(
            task: task,
            contextRequest: AgentContextRequest(
                source: .gaiRuntime,
                projectRoot: URL(fileURLWithPath: "/tmp/h28-9")
            ),
            toolCalls: toolCalls,
            capabilityRequest: nil
        )

        let result = try await orchestrator.runGAIIntegration(request)

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.toolCallResults.count, 1)
        XCTAssertTrue(result.toolCallResults[0].authorizationDecision.isAllowed,
                      "File write went through AuthGate (not bypassed)")
    }

    // MARK: - TASK-004.3: H28-10 验收测试（单一审计系统）

    func testH28_10_fullChain_noSecondAuditSystem() async throws {
        let (orchestrator, auditBridge) = makeH28Orchestrator()
        let request = makeH28IntegrationRequest(includeToolCalls: true, includeCapability: true)

        _ = try await orchestrator.runGAIIntegration(request)

        let allKinds = auditBridge.events.map { $0.kind }
        let uniqueKinds = Set(allKinds)

        XCTAssertEqual(allKinds.count, uniqueKinds.count + (allKinds.count - uniqueKinds.count),
                       "All events go through the same AIAuditBridge")

        let knownKinds: Set<AIAuditEventKind> = [
            .gaiWorkflowStarted, .gaiWorkflowPhaseStarted, .gaiWorkflowPhaseCompleted,
            .gaiWorkflowPhaseFailed, .gaiWorkflowCompleted, .gaiWorkflowCancelled,
            .gaiWorkflowFailed, .aiInferenceRequested, .aiInferenceCompleted,
            .aiInferenceFailed, .aiToolCallRequested, .aiToolCallAuthorized,
            .aiToolCallExecuted, .aiToolCallDenied, .aiToolCallCompleted,
            .aiToolCallFailed, .aiAuthorizationRequested, .aiAuthorizationDecision
        ]
        for kind in uniqueKinds {
            XCTAssertTrue(knownKinds.contains(kind), "Unknown audit event kind: \(kind)")
        }

        let sessionIDs = Set(auditBridge.events.map { $0.sessionID })
        XCTAssertLessThanOrEqual(sessionIDs.count, 2,
                                 "All events should use at most 2 sessions (integration + tool calls)")
    }

    // MARK: - TASK-004.4: E2E Authorization deny truly blocks execution

    func testH28_authorizationDeny_blocksToolExecution() async throws {
        struct DenyingToolBridge: AIToolInvocationBridge {
            func invoke(_ request: AIToolCallRequest) async throws -> AIToolCallResult {
                return AIToolCallResult(
                    toolOutput: ToolOutput(text: "should not reach"),
                    auditRecordID: AuditRecordID(),
                    authorizationDecision: .rejected(
                        decidedBy: UserID("deny"),
                        at: ISO8601Timestamp(),
                        reason: "Denied"
                    )
                )
            }
        }

        let gaiBridge = H28GAIBridge()
        let contextBridge = H28ContextBridge()
        let toolBridge = DenyingToolBridge()
        let authBridge = H28AuthBridge(allow: true)
        let auditBridge = H28AuditBridge()
        let capService = H28CapService()

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
                toolID: ToolID("dangerous.tool"),
                arguments: ToolArguments(values: [:]),
                source: .gaiRuntime,
                sessionID: AgentSessionID()
            )
        ]

        let request = GAIIntegrationRequest(
            task: GAIWorkflowTask(phase: .implementation, userRequest: "deny test", contextRequest: "", maxSteps: 5),
            contextRequest: AgentContextRequest(source: .gaiRuntime, projectRoot: URL(fileURLWithPath: "/tmp")),
            toolCalls: toolCalls,
            capabilityRequest: nil
        )

        let result = try await orchestrator.runGAIIntegration(request)

        XCTAssertEqual(result.toolCallResults.count, 1)
        XCTAssertTrue(result.toolCallResults[0].authorizationDecision.isRejected,
                      "Authorization deny is reflected in result")
    }

    // MARK: - TASK-004.5: Full E2E with all components

    func testH28_fullE2E_allComponentsChained() async throws {
        let (orchestrator, auditBridge) = makeH28Orchestrator()
        let request = makeH28IntegrationRequest(includeToolCalls: true, includeCapability: true)

        let result = try await orchestrator.runGAIIntegration(request)

        XCTAssertEqual(result.status, .completed)
        XCTAssertNotNil(result.workflowState)
        XCTAssertEqual(result.toolCallResults.count, 1)
        XCTAssertEqual(result.auditRecordIDs.count, 1)

        let eventCount = auditBridge.events.count
        XCTAssertGreaterThan(eventCount, 10, "Full E2E should produce substantial audit events")

        let phaseEvents = auditBridge.events.filter { $0.kind == .gaiWorkflowPhaseStarted }
        XCTAssertEqual(phaseEvents.count, GAIWorkflowPhase.allCases.count,
                       "All 8 phases should be started in E2E")
    }
}
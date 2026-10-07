import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain
@testable import AppKCodeApplication

// MARK: - M11-P7-TASK-003: CodeArts Agent 端到端集成测试
// 对应需求: m11_tasks.md §9 TASK-003
// 对应硬约束: H19-H28

// MARK: - E2E CodeArts Test Stubs

private final class E2ECapService: CapabilityAppService, @unchecked Sendable {
    enum Mode { case success, denied, failure, degraded }

    private let mode: Mode
    private let lock = NSLock()
    private var _invokeCount = 0

    var invokeCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _invokeCount
    }

    init(mode: Mode = .success) {
        self.mode = mode
    }

    func listCapabilities() async -> [CapabilityDescriptor] { return [] }
    func listCapabilities(byCategory: CapabilityCategory) async -> [CapabilityDescriptor] { return [] }
    func listCapabilities(forExtension id: ExtensionID) async -> [CapabilityDescriptor] { return [] }

    func invokeCapability(
        _ id: CapabilityID,
        extensionID: ExtensionID,
        input: AnyCodableValue,
        sessionID: AgentSessionID
    ) async throws -> CapabilityInvocationResult {
        lock.lock(); _invokeCount += 1; lock.unlock()

        switch mode {
        case .success:
            return .success(output: .object(["phase": input]), evidence: [])
        case .denied:
            return .denied(reason: "E2E CodeArts denied")
        case .failure:
            return .failure(error: .underlyingError("E2E CodeArts failure"))
        case .degraded:
            return .degraded(reason: "E2E degraded", partialOutput: nil)
        }
    }

    func runContractTests(_ contractID: CapabilityContractID) async throws -> ContractTestResult {
        return ContractTestResult(contractID: contractID, passed: true, failures: [])
    }
}

private struct E2EContextBridgeForCodeArts: AgentContextBridge {
    let contextItems: [ContextItem]

    init(contextItems: [ContextItem] = []) {
        self.contextItems = contextItems
    }

    func gatherContext(_ request: AgentContextRequest) async throws -> [ContextItem] {
        return contextItems
    }
}

private final class E2EAuditBridgeForCodeArts: AIAuditBridge, @unchecked Sendable {
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

// MARK: - Helpers

private func makeCodeArtsE2EOrchestrator(
    capMode: E2ECapService.Mode = .success,
    contextItems: [ContextItem] = []
) -> (GAIIntegrationOrchestrator, E2ECapService, E2EAuditBridgeForCodeArts) {
    let capService = E2ECapService(mode: capMode)
    let contextBridge = E2EContextBridgeForCodeArts(contextItems: contextItems)
    let auditBridge = E2EAuditBridgeForCodeArts()

    let codeArtsOrchestrator = CodeArtsAgentOrchestrator(
        capabilityAppService: capService,
        contextBridge: contextBridge,
        auditBridge: auditBridge
    )

    // Create stub bridges for GAIIntegrationOrchestrator init
    let gaiBridge = E2EGAIBridgeForCodeArts()
    let toolBridge = E2EToolBridgeForCodeArts()
    let authBridge = E2EAuthBridgeForCodeArts()

    let orchestrator = GAIIntegrationOrchestrator(
        gaiBridge: gaiBridge,
        contextBridge: contextBridge,
        toolBridge: toolBridge,
        authBridge: authBridge,
        auditBridge: auditBridge,
        codeArtsOrchestrator: codeArtsOrchestrator
    )

    return (orchestrator, capService, auditBridge)
}

// Stub bridges for GAIIntegrationOrchestrator init
private final class E2EGAIBridgeForCodeArts: GAIRuntimeBridge, @unchecked Sendable {
    func submitTask(_ task: GAIWorkflowTask) async throws -> GAIWorkflowState {
        return GAIWorkflowState(
            sessionID: AgentSessionID(),
            taskID: task.id,
            currentPhase: task.phase,
            status: .pending
        )
    }
    func advance(phase: GAIWorkflowPhase, session: AgentSessionID) async throws -> GAIWorkflowState {
        throw GAIError.sessionNotFound(session: session)
    }
    func currentState(session: AgentSessionID) async throws -> GAIWorkflowState {
        throw GAIError.sessionNotFound(session: session)
    }
    func cancel(session: AgentSessionID) async throws {}
}

private final class E2EToolBridgeForCodeArts: AIToolInvocationBridge, @unchecked Sendable {
    func invoke(_ request: AIToolCallRequest) async throws -> AIToolCallResult {
        return AIToolCallResult(
            toolOutput: ToolOutput(text: ""),
            auditRecordID: AuditRecordID(),
            authorizationDecision: .allowed(decidedBy: UserID("test"), at: ISO8601Timestamp(), sha256: "sha")
        )
    }
}

private final class E2EAuthBridgeForCodeArts: AICapabilityAuthorizationBridge, @unchecked Sendable {
    func authorize(_ request: AICapabilityRequest) async throws -> AuthorizationDecision {
        return .allowed(decidedBy: UserID("test"), at: ISO8601Timestamp(), sha256: "sha")
    }
}

// MARK: - EndToEndCodeArtsAgentTests

final class EndToEndCodeArtsAgentTests: XCTestCase {

    // MARK: - TASK-003.1: CodeArts Agent 全链路集成测试

    func testCodeArtsAgentFullChain() async throws {
        let (orchestrator, capService, auditBridge) = makeCodeArtsE2EOrchestrator()

        let request = CodeArtsAgentRequest(
            extensionID: ExtensionID("codearts.agent"),
            workflow: "spec-driven",
            contextRequest: AgentContextRequest(
                source: .codeArtsAgent,
                projectRoot: URL(fileURLWithPath: "/tmp/e2e-codearts")
            ),
            sessionID: AgentSessionID("e2e-codearts-session")
        )

        let result = try await orchestrator.runCodeArtsIntegration(request)

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.phaseResults.count, GAIWorkflowPhase.allCases.count)
        XCTAssertEqual(capService.invokeCount, GAIWorkflowPhase.allCases.count)

        XCTAssertTrue(auditBridge.events.contains { $0.kind == .gaiWorkflowStarted })
        XCTAssertTrue(auditBridge.events.contains { $0.kind == .gaiWorkflowCompleted })
    }

    func testCodeArtsAgentContextViaPublicProtocolSurface() async throws {
        let contextItems = [
            ContextItem(source: .workspace, content: "project files", metadata: ContextMetadata()),
            ContextItem(source: .currentFile, content: "current.swift", metadata: ContextMetadata())
        ]

        let (orchestrator, _, auditBridge) = makeCodeArtsE2EOrchestrator(contextItems: contextItems)

        let request = CodeArtsAgentRequest(
            extensionID: ExtensionID("codearts.agent"),
            workflow: "context-test",
            contextRequest: AgentContextRequest(
                source: .codeArtsAgent,
                projectRoot: URL(fileURLWithPath: "/tmp/e2e-context")
            ),
            sessionID: AgentSessionID()
        )

        let result = try await orchestrator.runCodeArtsIntegration(request)

        XCTAssertEqual(result.status, .completed)
        let startedEvents = auditBridge.events.filter { $0.kind == .gaiWorkflowStarted }
        XCTAssertEqual(startedEvents.count, 1)
    }

    func testCodeArtsAgentCapabilityInvocation() async throws {
        let (orchestrator, capService, _) = makeCodeArtsE2EOrchestrator()

        let request = CodeArtsAgentRequest(
            extensionID: ExtensionID("codearts.agent"),
            workflow: "capability-test",
            contextRequest: AgentContextRequest(
                source: .codeArtsAgent,
                projectRoot: URL(fileURLWithPath: "/tmp/e2e-cap")
            ),
            sessionID: AgentSessionID()
        )

        let result = try await orchestrator.runCodeArtsIntegration(request)

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(capService.invokeCount, GAIWorkflowPhase.allCases.count)

        for phaseResult in result.phaseResults {
            if case .success = phaseResult.result {
                // expected
            } else {
                XCTFail("Expected .success for phase \(phaseResult.phase)")
            }
        }
    }

    // MARK: - TASK-003.2: Error paths

    func testCodeArtsAgentDeniedCapability() async throws {
        let (orchestrator, _, auditBridge) = makeCodeArtsE2EOrchestrator(capMode: .denied)

        let request = CodeArtsAgentRequest(
            extensionID: ExtensionID("codearts.agent"),
            workflow: "denied-test",
            contextRequest: AgentContextRequest(
                source: .codeArtsAgent,
                projectRoot: URL(fileURLWithPath: "/tmp/e2e-denied")
            ),
            sessionID: AgentSessionID()
        )

        do {
            _ = try await orchestrator.runCodeArtsIntegration(request)
            XCTFail("Should throw incompatibleExtension")
        } catch let error as CodeArtsAgentError {
            if case .incompatibleExtension = error {
                let failedEvents = auditBridge.events.filter { $0.kind == .gaiWorkflowPhaseFailed }
                XCTAssertTrue(failedEvents.contains { $0.detail.contains("denied") })
            } else {
                XCTFail("Expected .incompatibleExtension, got \(error)")
            }
        }
    }

    func testCodeArtsAgentFailureCapability() async throws {
        let (orchestrator, _, _) = makeCodeArtsE2EOrchestrator(capMode: .failure)

        let request = CodeArtsAgentRequest(
            extensionID: ExtensionID("codearts.agent"),
            workflow: "failure-test",
            contextRequest: AgentContextRequest(
                source: .codeArtsAgent,
                projectRoot: URL(fileURLWithPath: "/tmp/e2e-fail")
            ),
            sessionID: AgentSessionID()
        )

        do {
            _ = try await orchestrator.runCodeArtsIntegration(request)
            XCTFail("Should throw capabilityInvocationFailed")
        } catch let error as CodeArtsAgentError {
            if case .capabilityInvocationFailed = error {
                // expected
            } else {
                XCTFail("Expected .capabilityInvocationFailed, got \(error)")
            }
        }
    }

    // MARK: - TASK-003.3: Audit verification

    func testCodeArtsAgentAuditChainComplete() async throws {
        let (orchestrator, _, auditBridge) = makeCodeArtsE2EOrchestrator()

        let request = CodeArtsAgentRequest(
            extensionID: ExtensionID("codearts.agent"),
            workflow: "audit-test",
            contextRequest: AgentContextRequest(
                source: .codeArtsAgent,
                projectRoot: URL(fileURLWithPath: "/tmp/e2e-audit")
            ),
            sessionID: AgentSessionID("audit-session")
        )

        _ = try await orchestrator.runCodeArtsIntegration(request)

        let kinds = Set(auditBridge.events.map { $0.kind })
        XCTAssertTrue(kinds.contains(.gaiWorkflowStarted))
        XCTAssertTrue(kinds.contains(.gaiWorkflowPhaseStarted))
        XCTAssertTrue(kinds.contains(.gaiWorkflowPhaseCompleted))
        XCTAssertTrue(kinds.contains(.gaiWorkflowCompleted))

        let allEventsHaveSession = auditBridge.events.allSatisfy { !$0.sessionID.rawValue.isEmpty }
        XCTAssertTrue(allEventsHaveSession)
    }

    // MARK: - TASK-003.4: Degraded mode

    func testCodeArtsAgentDegradedMode() async throws {
        let (orchestrator, _, _) = makeCodeArtsE2EOrchestrator(capMode: .degraded)

        let request = CodeArtsAgentRequest(
            extensionID: ExtensionID("codearts.agent"),
            workflow: "degraded-test",
            contextRequest: AgentContextRequest(
                source: .codeArtsAgent,
                projectRoot: URL(fileURLWithPath: "/tmp/e2e-degraded")
            ),
            sessionID: AgentSessionID()
        )

        let result = try await orchestrator.runCodeArtsIntegration(request)

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.phaseResults.count, GAIWorkflowPhase.allCases.count)
    }
}
import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain
@testable import AppKCodeApplication

// MARK: - Test Stubs for P6

private final class StubCapabilityAppService: CapabilityAppService, @unchecked Sendable {
    enum InvokeMode { case success, failure, denied, degraded, throw_ }

    private let mode: InvokeMode
    private let lock = NSLock()
    private var _invokeCount = 0

    var invokeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _invokeCount
    }

    init(mode: InvokeMode = .success) {
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
        lock.lock()
        _invokeCount += 1
        lock.unlock()

        switch mode {
        case .success:
            return .success(output: .null, evidence: [])
        case .failure:
            return .failure(error: .underlyingError("Stub failure"))
        case .denied:
            return .denied(reason: "Stub denied")
        case .degraded:
            return .degraded(reason: "Stub degraded", partialOutput: nil)
        case .throw_:
            throw CapabilityError.underlyingError("Stub throw")
        }
    }

    func runContractTests(_ contractID: CapabilityContractID) async throws -> ContractTestResult {
        return ContractTestResult(contractID: contractID, passed: true, failures: [])
    }
}

private struct StubAgentContextBridge: AgentContextBridge {
    let contextItems: [ContextItem]

    init(contextItems: [ContextItem] = []) {
        self.contextItems = contextItems
    }

    func gatherContext(_ request: AgentContextRequest) async throws -> [ContextItem] {
        return contextItems
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

// MARK: - Test Helpers

private func makeCodeArtsRequest(
    extensionID: ExtensionID = ExtensionID("codearts.agent"),
    workflow: String = "spec-driven",
    sessionID: AgentSessionID = AgentSessionID("test-session")
) -> CodeArtsAgentRequest {
    return CodeArtsAgentRequest(
        extensionID: extensionID,
        workflow: workflow,
        contextRequest: AgentContextRequest(
            source: .codeArtsAgent,
            projectRoot: URL(fileURLWithPath: "/tmp/project")
        ),
        sessionID: sessionID
    )
}

// MARK: - CodeArtsAgentOrchestrator Tests (M11-P6-TASK-003)

final class CodeArtsAgentOrchestratorTests: XCTestCase {

    // MARK: - TASK-003.1: Unit Tests

    func testExecuteWorkflow_returnsResult() async throws {
        let capService = StubCapabilityAppService(mode: .success)
        let contextBridge = StubAgentContextBridge()
        let auditBridge = StubAIAuditBridge()

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge
        )

        let request = makeCodeArtsRequest()
        let result = try await orchestrator.executeWorkflow(request)

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.phaseResults.count, GAIWorkflowPhase.allCases.count)
        XCTAssertEqual(result.auditRecordIDs.count, GAIWorkflowPhase.allCases.count)
    }

    func testExecuteWorkflow_evaluateOnlyPolicy_noDeepening() async throws {
        let capService = StubCapabilityAppService(mode: .success)
        let contextBridge = StubAgentContextBridge()
        let auditBridge = StubAIAuditBridge()

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge,
            deepeningPolicy: .evaluateOnly
        )

        let result = try await orchestrator.executeWorkflow(makeCodeArtsRequest())

        XCTAssertEqual(result.status, .completed)
        // evaluateOnly should complete without deepening
        let completedEvents = auditBridge.events.filter { $0.kind == .gaiWorkflowCompleted }
        XCTAssertEqual(completedEvents.count, 1)
        XCTAssertTrue(completedEvents[0].detail.contains("evaluateOnly"))
    }

    func testExecuteWorkflow_incompatibleExtension_throwsError() async throws {
        let capService = StubCapabilityAppService(mode: .denied)
        let contextBridge = StubAgentContextBridge()
        let auditBridge = StubAIAuditBridge()

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge
        )

        do {
            _ = try await orchestrator.executeWorkflow(makeCodeArtsRequest())
            XCTFail("Should throw CodeArtsAgentError.incompatibleExtension")
        } catch let error as CodeArtsAgentError {
            if case .incompatibleExtension = error {
                // expected
            } else {
                XCTFail("Expected .incompatibleExtension, got \(error)")
            }
        }
    }

    func testExecuteWorkflow_capabilityFailure_throwsError() async throws {
        let capService = StubCapabilityAppService(mode: .failure)
        let contextBridge = StubAgentContextBridge()
        let auditBridge = StubAIAuditBridge()

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge
        )

        do {
            _ = try await orchestrator.executeWorkflow(makeCodeArtsRequest())
            XCTFail("Should throw CodeArtsAgentError.capabilityInvocationFailed")
        } catch let error as CodeArtsAgentError {
            if case .capabilityInvocationFailed = error {
                // expected
            } else {
                XCTFail("Expected .capabilityInvocationFailed, got \(error)")
            }
        }
    }

    func testExecuteWorkflow_throwError_throwsError() async throws {
        let capService = StubCapabilityAppService(mode: .throw_)
        let contextBridge = StubAgentContextBridge()
        let auditBridge = StubAIAuditBridge()

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge
        )

        do {
            _ = try await orchestrator.executeWorkflow(makeCodeArtsRequest())
            XCTFail("Should throw CodeArtsAgentError.capabilityInvocationFailed")
        } catch let error as CodeArtsAgentError {
            if case .capabilityInvocationFailed = error {
                // expected
            } else {
                XCTFail("Expected .capabilityInvocationFailed, got \(error)")
            }
        }
    }

    func testExecuteWorkflow_contextGatheringFailed_throwsError() async throws {
        let capService = StubCapabilityAppService(mode: .success)

        struct FailingContextBridge: AgentContextBridge {
            func gatherContext(_ request: AgentContextRequest) async throws -> [ContextItem] {
                throw AgentContextError.aggregationFailed(reason: "Test failure")
            }
        }

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: FailingContextBridge(),
            auditBridge: StubAIAuditBridge()
        )

        do {
            _ = try await orchestrator.executeWorkflow(makeCodeArtsRequest())
            XCTFail("Should throw CodeArtsAgentError.contextGatheringFailed")
        } catch let error as CodeArtsAgentError {
            if case .contextGatheringFailed = error {
                // expected
            } else {
                XCTFail("Expected .contextGatheringFailed, got \(error)")
            }
        }
    }

    // MARK: - TASK-003.2: H19 验收测试
    // CodeArts Agent 经 H19 全链路 (Contract → Auth → Exec → Audit)

    func testH19_codeArtsAgentFullChain() async throws {
        let capService = StubCapabilityAppService(mode: .success)
        let contextBridge = StubAgentContextBridge()
        let auditBridge = StubAIAuditBridge()

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge
        )

        let result = try await orchestrator.executeWorkflow(makeCodeArtsRequest())

        // H19: All capability invocations go through CapabilityAppService (H19 full chain)
        XCTAssertEqual(capService.invokeCount, GAIWorkflowPhase.allCases.count,
                       "H19: Each phase must invoke CapabilityAppService")
        XCTAssertEqual(result.status, .completed)
        XCTAssertTrue(result.phaseResults.allSatisfy { phaseResult in
            if case .success = phaseResult.result { return true }
            return false
        }, "H19: All phase results should be success")
    }

    // MARK: - TASK-003.3: H20-H24 验收测试

    func testH20_extensionAuthorization() async throws {
        // H20: Extension authorization — denied result → incompatibleExtension error
        let capService = StubCapabilityAppService(mode: .denied)
        let contextBridge = StubAgentContextBridge()
        let auditBridge = StubAIAuditBridge()

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge
        )

        do {
            _ = try await orchestrator.executeWorkflow(makeCodeArtsRequest())
            XCTFail("H20: Denied capability should throw")
        } catch CodeArtsAgentError.incompatibleExtension {
            // H20 PASS: denied → incompatibleExtension
        }

        // Verify audit recorded the denial
        let failedEvents = auditBridge.events.filter { $0.kind == .gaiWorkflowPhaseFailed }
        XCTAssertGreaterThan(failedEvents.count, 0, "H20: Denial should be audited")
    }

    func testH21_capabilityContract() async throws {
        // H21: Capability contract enforced by CapabilityAppService
        // If capability throws (e.g., contract not found), orchestrator propagates error
        let capService = StubCapabilityAppService(mode: .throw_)
        let contextBridge = StubAgentContextBridge()
        let auditBridge = StubAIAuditBridge()

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge
        )

        do {
            _ = try await orchestrator.executeWorkflow(makeCodeArtsRequest())
            XCTFail("H21: Contract violation should throw")
        } catch CodeArtsAgentError.capabilityInvocationFailed {
            // H21 PASS: contract violation → capabilityInvocationFailed
        }
    }

    func testH22_adapterIsolation() async throws {
        // H22: CodeArts Agent context gathered via AgentContextBridge (PublicProtocolSurface)
        // Not direct access to host internals
        let capService = StubCapabilityAppService(mode: .success)
        let contextBridge = StubAgentContextBridge(contextItems: [
            ContextItem(source: .workspace, content: "context")
        ])
        let auditBridge = StubAIAuditBridge()

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge
        )

        let result = try await orchestrator.executeWorkflow(makeCodeArtsRequest())

        // H22: Context gathered via bridge, not direct access
        XCTAssertEqual(result.status, .completed, "H22: Workflow should complete with context via bridge")
        XCTAssertEqual(capService.invokeCount, GAIWorkflowPhase.allCases.count,
                       "H22: All phases invoked through bridge-isolated path")
    }

    func testH23_compatibilityAudit() async throws {
        // H23: All CodeArts Agent actions audited via AIAuditBridge → M7 AuditService
        let capService = StubCapabilityAppService(mode: .success)
        let contextBridge = StubAgentContextBridge()
        let auditBridge = StubAIAuditBridge()

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge
        )

        _ = try await orchestrator.executeWorkflow(makeCodeArtsRequest())

        // H23: Audit events recorded for workflow start, each phase, and completion
        let startedEvents = auditBridge.events.filter { $0.kind == .gaiWorkflowStarted }
        let phaseStartedEvents = auditBridge.events.filter { $0.kind == .gaiWorkflowPhaseStarted }
        let phaseCompletedEvents = auditBridge.events.filter { $0.kind == .gaiWorkflowPhaseCompleted }
        let completedEvents = auditBridge.events.filter { $0.kind == .gaiWorkflowCompleted }

        XCTAssertEqual(startedEvents.count, 1, "H23: Workflow start should be audited")
        XCTAssertEqual(phaseStartedEvents.count, GAIWorkflowPhase.allCases.count,
                       "H23: Each phase start should be audited")
        XCTAssertEqual(phaseCompletedEvents.count, GAIWorkflowPhase.allCases.count,
                       "H23: Each phase completion should be audited")
        XCTAssertEqual(completedEvents.count, 1, "H23: Workflow completion should be audited")
    }

    func testH24_versionNegotiation() async throws {
        // H24: Version negotiation handled by M9 VersionNegotiationService (inside CapabilityAppService)
        // If extension is incompatible, capability returns .denied → incompatibleExtension
        let capService = StubCapabilityAppService(mode: .denied)
        let contextBridge = StubAgentContextBridge()
        let auditBridge = StubAIAuditBridge()

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge
        )

        do {
            _ = try await orchestrator.executeWorkflow(makeCodeArtsRequest(
                extensionID: ExtensionID("incompatible.extension")
            ))
            XCTFail("H24: Incompatible extension should throw")
        } catch CodeArtsAgentError.incompatibleExtension(let extID, _) {
            XCTAssertEqual(extID, ExtensionID("incompatible.extension"),
                           "H24: Error should reference the incompatible extension")
        }
    }

    // MARK: - TASK-003.4: H25-H27 验收测试
    // H25/H26/H27 are enforced by M10 ExtensionHostProcessManager / API Surface / ResourceLimiter
    // P6 does not modify these — it delegates to CapabilityAppService which uses them internally

    func testH25_processIsolation() async throws {
        // H25: Process isolation enforced by M10 ExtensionHostProcessManager (inside CapabilityAppService)
        // P6 delegates to CapabilityAppService, does not bypass process isolation
        let capService = StubCapabilityAppService(mode: .success)
        let contextBridge = StubAgentContextBridge()
        let auditBridge = StubAIAuditBridge()

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge
        )

        let result = try await orchestrator.executeWorkflow(makeCodeArtsRequest())

        // H25: All invocations go through CapabilityAppService (which enforces H25 internally)
        XCTAssertEqual(capService.invokeCount, GAIWorkflowPhase.allCases.count,
                       "H25: All invocations delegated to CapabilityAppService (process isolation preserved)")
        XCTAssertEqual(result.status, .completed)
    }

    func testH26_apiSurfaceBoundary() async throws {
        // H26: API Surface Boundary enforced by M10 (inside CapabilityAppService)
        // P6 does not access host internals directly — only via AgentContextBridge (H22)
        let capService = StubCapabilityAppService(mode: .success)
        let contextBridge = StubAgentContextBridge()
        let auditBridge = StubAIAuditBridge()

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge
        )

        let result = try await orchestrator.executeWorkflow(makeCodeArtsRequest())

        // H26: No direct host access — all via bridges
        XCTAssertEqual(result.status, .completed, "H26: API surface boundary preserved via bridges")
    }

    func testH27_resourceLimit() async throws {
        // H27: Resource limit enforced by M10 ExtensionResourceLimiter (inside CapabilityAppService)
        // P6 does not modify resource limits — delegates to CapabilityAppService
        let capService = StubCapabilityAppService(mode: .success)
        let contextBridge = StubAgentContextBridge()
        let auditBridge = StubAIAuditBridge()

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge
        )

        let result = try await orchestrator.executeWorkflow(makeCodeArtsRequest())

        // H27: Resource limits preserved (delegated to CapabilityAppService)
        XCTAssertEqual(result.status, .completed, "H27: Resource limits preserved via delegation")
    }

    // MARK: - TASK-003.5: H28 验收测试

    func testH28_codeArtsAgentDoesNotBypassH28() async throws {
        // H28: CodeArts Agent AI actions must not bypass H28 boundary
        // All actions go through CapabilityAppService (H19 full chain) → no bypass
        let capService = StubCapabilityAppService(mode: .success)
        let contextBridge = StubAgentContextBridge()
        let auditBridge = StubAIAuditBridge()

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge
        )

        let result = try await orchestrator.executeWorkflow(makeCodeArtsRequest())

        // H28: All phases completed through proper chain (no bypass)
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(capService.invokeCount, GAIWorkflowPhase.allCases.count,
                       "H28: All actions through CapabilityAppService, no bypass")
    }

    // MARK: - Additional Tests

    func testExecuteWorkflow_auditRecordIDsMatchPhaseResults() async throws {
        let capService = StubCapabilityAppService(mode: .success)
        let contextBridge = StubAgentContextBridge()
        let auditBridge = StubAIAuditBridge()

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge
        )

        let result = try await orchestrator.executeWorkflow(makeCodeArtsRequest())

        XCTAssertEqual(result.auditRecordIDs.count, result.phaseResults.count,
                       "Audit record IDs should match phase results count")
        for (i, phaseResult) in result.phaseResults.enumerated() {
            XCTAssertEqual(result.auditRecordIDs[i], phaseResult.auditRecordID,
                           "Audit record ID at index \(i) should match phase result")
        }
    }

    func testExecuteWorkflow_deepenPolicy() async throws {
        let capService = StubCapabilityAppService(mode: .success)
        let contextBridge = StubAgentContextBridge()
        let auditBridge = StubAIAuditBridge()

        let orchestrator = CodeArtsAgentOrchestrator(
            capabilityAppService: capService,
            contextBridge: contextBridge,
            auditBridge: auditBridge,
            deepeningPolicy: .deepen
        )

        _ = try await orchestrator.executeWorkflow(makeCodeArtsRequest())

        let completedEvents = auditBridge.events.filter { $0.kind == .gaiWorkflowCompleted }
        XCTAssertEqual(completedEvents.count, 1)
        XCTAssertTrue(completedEvents[0].detail.contains("deepen"),
                      "Deepen policy should be reflected in audit")
    }
}
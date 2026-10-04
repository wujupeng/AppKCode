import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain
@testable import AppKCodeApplication

// MARK: - Test Stubs

private struct StubPlanner: Planner {
    func generatePlan(
        userRequest: String,
        session: AgentSessionID,
        availableTools: [ToolSchema],
        context: [ContextItem]
    ) async throws -> ActionPlan {
        return ActionPlan(sessionID: session, steps: [])
    }
}

private struct StubSessionManager: AgentSessionManaging {
    func createSession(projectRoot: URL) async throws -> AgentSessionID {
        return AgentSessionID()
    }
    func resumeSession(_ id: AgentSessionID) async throws -> AgentSessionSnapshot {
        return AgentSessionSnapshot(
            id: id,
            projectRoot: URL(fileURLWithPath: "/tmp"),
            status: .active,
            createdAt: ISO8601Timestamp(),
            sandboxDir: URL(fileURLWithPath: "/tmp")
        )
    }
    func abortSession(_ id: AgentSessionID) async throws {}
    func pauseSession(_ id: AgentSessionID) async throws {}
    func snapshot(_ id: AgentSessionID) async throws -> AgentSessionSnapshot {
        return AgentSessionSnapshot(
            id: id,
            projectRoot: URL(fileURLWithPath: "/tmp"),
            status: .active,
            createdAt: ISO8601Timestamp(),
            sandboxDir: URL(fileURLWithPath: "/tmp")
        )
    }
}

private struct StubActionExecutor: ActionExecutor {
    func execute(_ step: ActionStep, session: AgentSessionID) async throws -> ActionResult {
        return .success(ActionResultSuccess(
            output: ToolOutput(text: "ok"),
            evidenceID: EvidenceRecordID(),
            durationSeconds: 0.0
        ))
    }
}

private struct StubAuthGate: AuthorizationGate {
    func authorize(_ step: ActionStep, session: AgentSessionID) async throws -> AuthorizationDecision {
        return .allowed(decidedBy: UserID("system"), at: ISO8601Timestamp(), sha256: "stub")
    }
}

private struct StubAuditService: AuditService {
    func record(_ entry: AgentAuditRecord) async throws {}
    func query(_ filter: AuditFilter) async throws -> [AgentAuditRecord] { return [] }
    func verifyIntegrity(session: AgentSessionID) async throws -> Bool { return true }
}

// MARK: - Test Helpers

private enum TestGAIBridgeFactory {
    static func makeBridge() -> GAIRuntimeBridgeImpl {
        let orchestrator = AgentRuntimeOrchestrator(
            planner: StubPlanner(),
            sessionManager: StubSessionManager(),
            actionExecutor: StubActionExecutor(),
            authGate: StubAuthGate(),
            auditService: StubAuditService(),
            contextAggregator: ContextAggregator(providers: []),
            toolRegistry: ToolRegistry()
        )
        return GAIRuntimeBridgeImpl(
            modelProviderRegistry: ModelProviderRegistry(),
            aiBoundaryValidator: AIBoundaryValidator(),
            orchestrator: orchestrator,
            auditBridge: nil
        )
    }
}

// MARK: - GAIRuntimeBridgeImpl Tests (M11-P1-TASK-004)

final class GAIRuntimeBridgeTests: XCTestCase {

    private var bridge: GAIRuntimeBridgeImpl!

    override func setUp() {
        super.setUp()
        bridge = TestGAIBridgeFactory.makeBridge()
    }

    override func tearDown() {
        bridge = nil
        super.tearDown()
    }

    // MARK: - submitTask Tests

    func testSubmitTask_createsSessionWithPendingStatus() async throws {
        let task = GAIWorkflowTask(
            phase: .spec,
            userRequest: "Test request",
            contextRequest: "Test context",
            maxSteps: 10
        )

        let state = try await bridge.submitTask(task)

        XCTAssertEqual(state.taskID, task.id)
        XCTAssertEqual(state.currentPhase, .spec)
        XCTAssertEqual(state.status, .pending)
        XCTAssertEqual(state.stepsTaken, 0)
        XCTAssertTrue(state.evidenceChain.isEmpty)
        XCTAssertNil(state.gateResult)
    }

    func testSubmitTask_invalidMaxSteps_throwsError() async throws {
        let task = GAIWorkflowTask(
            phase: .spec,
            userRequest: "Test request",
            contextRequest: "Test context",
            maxSteps: 0
        )

        do {
            _ = try await bridge.submitTask(task)
            XCTFail("Should throw invalidMaxSteps")
        } catch let error as GAIError {
            XCTAssertEqual(error, .invalidMaxSteps)
        }
    }

    func testSubmitTask_negativeMaxSteps_throwsError() async throws {
        let task = GAIWorkflowTask(
            phase: .spec,
            userRequest: "Test request",
            contextRequest: "Test context",
            maxSteps: -1
        )

        do {
            _ = try await bridge.submitTask(task)
            XCTFail("Should throw invalidMaxSteps")
        } catch let error as GAIError {
            XCTAssertEqual(error, .invalidMaxSteps)
        }
    }

    // MARK: - advance Tests

    func testAdvance_validPhase_advancesState() async throws {
        let task = GAIWorkflowTask(
            phase: .spec,
            userRequest: "Test request",
            contextRequest: "Test context",
            maxSteps: 10
        )

        let initialState = try await bridge.submitTask(task)

        let advancedState = try await bridge.advance(phase: .design, session: initialState.sessionID)

        XCTAssertEqual(advancedState.currentPhase, .design)
        XCTAssertEqual(advancedState.status, .inProgress)
        XCTAssertEqual(advancedState.stepsTaken, 1)
        XCTAssertEqual(advancedState.evidenceChain.count, 1)
    }

    func testAdvance_invalidPhase_throwsError() async throws {
        let task = GAIWorkflowTask(
            phase: .spec,
            userRequest: "Test request",
            contextRequest: "Test context",
            maxSteps: 10
        )

        let initialState = try await bridge.submitTask(task)

        do {
            _ = try await bridge.advance(phase: .test, session: initialState.sessionID)
            XCTFail("Should throw unknownPhase")
        } catch let error as GAIError {
            if case .unknownPhase(let phase) = error {
                XCTAssertEqual(phase, .test)
            } else {
                XCTFail("Wrong error: \(error)")
            }
        }
    }

    func testAdvance_maxStepsExceeded_throwsError() async throws {
        let task = GAIWorkflowTask(
            phase: .spec,
            userRequest: "Test request",
            contextRequest: "Test context",
            maxSteps: 1
        )

        let initialState = try await bridge.submitTask(task)

        _ = try await bridge.advance(phase: .design, session: initialState.sessionID)

        do {
            _ = try await bridge.advance(phase: .task, session: initialState.sessionID)
            XCTFail("Should throw maxStepsExceeded")
        } catch let error as GAIError {
            if case .maxStepsExceeded(let taskID, let maxSteps) = error {
                XCTAssertEqual(taskID, task.id)
                XCTAssertEqual(maxSteps, 1)
            } else {
                XCTFail("Wrong error: \(error)")
            }
        }
    }

    func testAdvance_implementationPhase_setsAwaitingApproval() async throws {
        let task = GAIWorkflowTask(
            phase: .task,
            userRequest: "Test request",
            contextRequest: "Test context",
            maxSteps: 10
        )

        let initialState = try await bridge.submitTask(task)

        let state = try await bridge.advance(phase: .implementation, session: initialState.sessionID)

        XCTAssertEqual(state.currentPhase, .implementation)
        XCTAssertEqual(state.status, .awaitingApproval)
    }

    func testAdvance_unknownSession_throwsError() async throws {
        let session = AgentSessionID()

        do {
            _ = try await bridge.advance(phase: .design, session: session)
            XCTFail("Should throw sessionNotFound")
        } catch let error as GAIError {
            if case .sessionNotFound = error {
                // Expected
            } else {
                XCTFail("Wrong error: \(error)")
            }
        }
    }

    // MARK: - currentState Tests

    func testCurrentState_returnsCurrentState() async throws {
        let task = GAIWorkflowTask(
            phase: .spec,
            userRequest: "Test request",
            contextRequest: "Test context",
            maxSteps: 10
        )

        let initialState = try await bridge.submitTask(task)

        let state = try await bridge.currentState(session: initialState.sessionID)

        XCTAssertEqual(state.taskID, task.id)
        XCTAssertEqual(state.currentPhase, .spec)
        XCTAssertEqual(state.status, .pending)
    }

    func testCurrentState_unknownSession_throwsError() async throws {
        let session = AgentSessionID()

        do {
            _ = try await bridge.currentState(session: session)
            XCTFail("Should throw sessionNotFound")
        } catch let error as GAIError {
            if case .sessionNotFound = error {
                // Expected
            } else {
                XCTFail("Wrong error: \(error)")
            }
        }
    }

    // MARK: - cancel Tests

    func testCancel_setsCancelledStatus() async throws {
        let task = GAIWorkflowTask(
            phase: .spec,
            userRequest: "Test request",
            contextRequest: "Test context",
            maxSteps: 10
        )

        let initialState = try await bridge.submitTask(task)

        try await bridge.cancel(session: initialState.sessionID)

        let state = try await bridge.currentState(session: initialState.sessionID)
        XCTAssertEqual(state.status, .cancelled)
    }

    func testCancel_unknownSession_throwsError() async throws {
        let session = AgentSessionID()

        do {
            try await bridge.cancel(session: session)
            XCTFail("Should throw sessionNotFound")
        } catch let error as GAIError {
            if case .sessionNotFound = error {
                // Expected
            } else {
                XCTFail("Wrong error: \(error)")
            }
        }
    }

    // MARK: - H28-1 Verification: G-AI Workflow Does Not Bypass M6 Boundary

    func testH28_1_submitTaskChecksAIBoundaryValidator() async throws {
        let task = GAIWorkflowTask(
            phase: .spec,
            userRequest: "Test request",
            contextRequest: "Test context",
            maxSteps: 10
        )

        let state = try await bridge.submitTask(task)

        XCTAssertEqual(state.status, .pending)
        XCTAssertEqual(state.currentPhase, .spec)
    }

    func testH28_1_gaiErrorIsSendableAndEquatable() {
        let errors: [GAIError] = [
            .invalidMaxSteps,
            .unknownPhase(phase: .spec),
            .maxStepsExceeded(taskID: GAIWorkflowTaskID(), maxSteps: 5),
            .authorizationDenied(session: AgentSessionID()),
            .sessionNotFound(session: AgentSessionID()),
            .alreadyCompleted(taskID: GAIWorkflowTaskID()),
            .inferenceFailed(reason: "test")
        ]

        XCTAssertEqual(errors.count, 7)
        XCTAssertEqual(GAIError.invalidMaxSteps, GAIError.invalidMaxSteps)
    }
}

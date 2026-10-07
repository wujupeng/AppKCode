import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain
@testable import AppKCodeApplication

// MARK: - Test Stubs for P5

private final class StubAuditService: AuditService, @unchecked Sendable {
    private let lock = NSLock()
    private var _records: [AgentAuditRecord] = []

    var records: [AgentAuditRecord] {
        lock.lock()
        defer { lock.unlock() }
        return _records
    }

    func record(_ entry: AgentAuditRecord) async throws {
        lock.lock()
        _records.append(entry)
        lock.unlock()
    }

    func query(_ filter: AuditFilter) async throws -> [AgentAuditRecord] {
        lock.lock()
        defer { lock.unlock() }
        return _records
    }

    func verifyIntegrity(session: AgentSessionID) async throws -> Bool {
        return true
    }
}

// MARK: - Test Helpers

private func makeAuditEvent(
    kind: AIAuditEventKind,
    sessionID: AgentSessionID = AgentSessionID("test-session"),
    phase: GAIWorkflowPhase? = nil,
    detail: String = "test detail"
) -> AIAuditEvent {
    return AIAuditEvent(
        kind: kind,
        sessionID: sessionID,
        taskID: nil,
        phase: phase,
        detail: detail
    )
}

// MARK: - AIAuditBridgeImpl Tests (M11-P5-TASK-004)

final class AIAuditBridgeTests: XCTestCase {

    // MARK: - TASK-004.1: Unit Tests

    func testRecord_returnsSuccessfully() async throws {
        let stub = StubAuditService()
        let bridge = AIAuditBridgeImpl(auditService: stub)

        let event = makeAuditEvent(kind: .aiInferenceRequested)
        try await bridge.record(event)

        XCTAssertEqual(stub.records.count, 1)
    }

    func testRecord_allEventKinds() async throws {
        let stub = StubAuditService()
        let bridge = AIAuditBridgeImpl(auditService: stub)

        let allKinds: [AIAuditEventKind] = [
            .gaiWorkflowStarted,
            .gaiWorkflowPhaseStarted,
            .gaiWorkflowPhaseCompleted,
            .gaiWorkflowPhaseFailed,
            .gaiWorkflowCompleted,
            .gaiWorkflowCancelled,
            .gaiWorkflowFailed,
            .aiInferenceRequested,
            .aiInferenceCompleted,
            .aiInferenceFailed,
            .aiToolCallRequested,
            .aiToolCallAuthorized,
            .aiToolCallExecuted,
            .aiToolCallDenied,
            .aiToolCallCompleted,
            .aiToolCallFailed,
            .aiAuthorizationRequested,
            .aiAuthorizationDecision
        ]

        for kind in allKinds {
            let event = makeAuditEvent(kind: kind, phase: .spec)
            try await bridge.record(event)
        }

        XCTAssertEqual(stub.records.count, allKinds.count, "All 18 event kinds should be recorded")
    }

    func testRecord_aiInferenceTarget() async throws {
        let stub = StubAuditService()
        let bridge = AIAuditBridgeImpl(auditService: stub)

        try await bridge.record(makeAuditEvent(kind: .aiInferenceRequested))
        try await bridge.record(makeAuditEvent(kind: .aiInferenceCompleted))
        try await bridge.record(makeAuditEvent(kind: .aiInferenceFailed))

        XCTAssertEqual(stub.records.count, 3)
        for record in stub.records {
            if case .aiInference = record.target {
                // expected
            } else {
                XCTFail("Expected .aiInference target, got \(record.target)")
            }
        }
    }

    func testRecord_gaiRuntimeTarget() async throws {
        let stub = StubAuditService()
        let bridge = AIAuditBridgeImpl(auditService: stub)

        try await bridge.record(makeAuditEvent(kind: .gaiWorkflowPhaseStarted, phase: .spec))
        try await bridge.record(makeAuditEvent(kind: .gaiWorkflowPhaseCompleted, phase: .design))
        try await bridge.record(makeAuditEvent(kind: .gaiWorkflowPhaseFailed, phase: .task))

        XCTAssertEqual(stub.records.count, 3)
        for record in stub.records {
            if case .gaiRuntime = record.target {
                // expected
            } else {
                XCTFail("Expected .gaiRuntime target, got \(record.target)")
            }
        }
    }

    func testRecord_aiToolCallTarget() async throws {
        let stub = StubAuditService()
        let bridge = AIAuditBridgeImpl(auditService: stub)

        try await bridge.record(makeAuditEvent(kind: .aiToolCallRequested))
        try await bridge.record(makeAuditEvent(kind: .aiToolCallAuthorized))
        try await bridge.record(makeAuditEvent(kind: .aiToolCallExecuted))
        try await bridge.record(makeAuditEvent(kind: .aiToolCallDenied))
        try await bridge.record(makeAuditEvent(kind: .aiToolCallCompleted))
        try await bridge.record(makeAuditEvent(kind: .aiToolCallFailed))

        XCTAssertEqual(stub.records.count, 6)
        for record in stub.records {
            if case .aiToolCall = record.target {
                // expected
            } else {
                XCTFail("Expected .aiToolCall target, got \(record.target)")
            }
        }
    }

    func testRecord_failureEvents_haveCorrectResult() async throws {
        let stub = StubAuditService()
        let bridge = AIAuditBridgeImpl(auditService: stub)

        let failureKinds: [AIAuditEventKind] = [
            .aiInferenceFailed, .gaiWorkflowPhaseFailed, .gaiWorkflowFailed,
            .aiToolCallFailed, .aiToolCallDenied
        ]

        for kind in failureKinds {
            try await bridge.record(makeAuditEvent(kind: kind, detail: "failure: \(kind.rawValue)"))
        }

        XCTAssertEqual(stub.records.count, failureKinds.count)
        for record in stub.records {
            if case .failure = record.result {
                // expected
            } else {
                XCTFail("Expected .failure result, got \(record.result)")
            }
            XCTAssertNotNil(record.error, "Failure events should have non-nil error")
        }
    }

    func testRecord_cancelledEvent_hasCancelledResult() async throws {
        let stub = StubAuditService()
        let bridge = AIAuditBridgeImpl(auditService: stub)

        try await bridge.record(makeAuditEvent(kind: .gaiWorkflowCancelled))

        XCTAssertEqual(stub.records.count, 1)
        if case .cancelled = stub.records[0].result {
            // expected
        } else {
            XCTFail("Expected .cancelled result, got \(stub.records[0].result)")
        }
    }

    func testRecord_successEvents_haveSuccessResult() async throws {
        let stub = StubAuditService()
        let bridge = AIAuditBridgeImpl(auditService: stub)

        let successKinds: [AIAuditEventKind] = [
            .gaiWorkflowStarted, .gaiWorkflowPhaseStarted, .gaiWorkflowPhaseCompleted,
            .gaiWorkflowCompleted, .aiInferenceRequested, .aiInferenceCompleted,
            .aiToolCallRequested, .aiToolCallAuthorized, .aiToolCallExecuted,
            .aiToolCallCompleted, .aiAuthorizationRequested, .aiAuthorizationDecision
        ]

        for kind in successKinds {
            try await bridge.record(makeAuditEvent(kind: kind))
        }

        XCTAssertEqual(stub.records.count, successKinds.count)
        for record in stub.records {
            if case .success = record.result {
                // expected
            } else {
                XCTFail("Expected .success result, got \(record.result)")
            }
        }
    }

    // MARK: - TASK-004.2: H28-6 验收测试
    // 所有 AI 动作经 M7 AuditService 审计 (H14, H28-6)

    func testH28_6_allAIActionsViaAuditService() async throws {
        let stub = StubAuditService()
        let bridge = AIAuditBridgeImpl(auditService: stub)

        // Record representative events from each category
        try await bridge.record(makeAuditEvent(kind: .aiInferenceRequested, detail: "inference"))
        try await bridge.record(makeAuditEvent(kind: .gaiWorkflowPhaseStarted, phase: .spec, detail: "workflow"))
        try await bridge.record(makeAuditEvent(kind: .aiToolCallRequested, detail: "tool call"))
        try await bridge.record(makeAuditEvent(kind: .aiAuthorizationRequested, detail: "authz"))

        // H28-6: All AI actions must be recorded via AuditService
        XCTAssertEqual(stub.records.count, 4, "H28-6: All AI actions must produce audit records")

        // H14: Each record must have all 8 fields + SHA-256
        for record in stub.records {
            XCTAssertFalse(record.id.rawValue.isEmpty, "H14: id must be non-empty")
            XCTAssertFalse(record.timestamp.rawValue.isEmpty, "H14: timestamp must be non-empty")
            XCTAssertFalse(record.sessionID.rawValue.isEmpty, "H14: sessionID must be non-empty")
            XCTAssertFalse(record.tool.rawValue.isEmpty, "H14: tool must be non-empty")
            XCTAssertFalse(record.sha256.isEmpty, "H14: sha256 must be non-empty")
        }
    }

    func testH28_6_auditTargetExtensionsCovered() async throws {
        let stub = StubAuditService()
        let bridge = AIAuditBridgeImpl(auditService: stub)

        // aiInference target
        try await bridge.record(makeAuditEvent(kind: .aiInferenceRequested))
        // gaiRuntime target
        try await bridge.record(makeAuditEvent(kind: .gaiWorkflowPhaseStarted, phase: .implementation))
        // aiToolCall target
        try await bridge.record(makeAuditEvent(kind: .aiToolCallExecuted))

        XCTAssertEqual(stub.records.count, 3)

        if case .aiInference(let endpoint) = stub.records[0].target {
            XCTAssertEqual(endpoint, "default")
        } else {
            XCTFail("H28-6: First record should have .aiInference target")
        }

        if case .gaiRuntime(let phase) = stub.records[1].target {
            XCTAssertEqual(phase, "implementation")
        } else {
            XCTFail("H28-6: Second record should have .gaiRuntime target")
        }

        if case .aiToolCall = stub.records[2].target {
            // expected
        } else {
            XCTFail("H28-6: Third record should have .aiToolCall target")
        }
    }

    // MARK: - TASK-004.3: H28-10 验收测试
    // 不存在第二套审计系统，单一 AuditService 入口 (H23, H28-10)

    func testH28_10_noSecondAuditSystem() async throws {
        let stub = StubAuditService()
        let bridge = AIAuditBridgeImpl(auditService: stub)

        // H28-10: AIAuditBridgeImpl must delegate to M7 AuditService, not create a second audit system
        // This is verified by:
        // 1. AIAuditBridgeImpl takes AuditService as dependency (constructor injection)
        // 2. record() calls auditService.record() (delegation, not self-recording)
        // 3. No separate AuditLogStore or AuditServiceImpl is created inside AIAuditBridgeImpl

        let event = makeAuditEvent(kind: .aiInferenceRequested)
        try await bridge.record(event)

        // The record should appear in the AuditService's records (proving delegation)
        XCTAssertEqual(stub.records.count, 1, "H28-10: Record must be delegated to AuditService")
    }

    func testH28_10_singleAuditEntryPoint() async throws {
        // H28-10: All AI audit events go through the same AuditService.record entry point
        let stub = StubAuditService()
        let bridge = AIAuditBridgeImpl(auditService: stub)

        // Record different types of events
        try await bridge.record(makeAuditEvent(kind: .aiInferenceRequested))
        try await bridge.record(makeAuditEvent(kind: .aiToolCallRequested))
        try await bridge.record(makeAuditEvent(kind: .gaiWorkflowStarted))
        try await bridge.record(makeAuditEvent(kind: .aiAuthorizationDecision))

        // All records should be in the same AuditService (single entry point)
        XCTAssertEqual(stub.records.count, 4, "H28-10: All events must go through single AuditService")

        // All records should have the same tool ID (ai-audit), proving they all came through AIAuditBridgeImpl
        for record in stub.records {
            XCTAssertEqual(record.tool, ToolID("ai-audit"), "H28-10: All records must come through AIAuditBridgeImpl")
        }
    }

    // MARK: - TASK-004.4: H14 Regression Tests

    func testH14_auditRecordHasAll8Fields() async throws {
        let stub = StubAuditService()
        let bridge = AIAuditBridgeImpl(auditService: stub)

        try await bridge.record(makeAuditEvent(kind: .aiInferenceRequested, detail: "H14 test"))

        XCTAssertEqual(stub.records.count, 1)
        let record = stub.records[0]

        // H14: AgentAuditRecord must have all 8 fields + SHA-256
        // 1. id
        XCTAssertFalse(record.id.rawValue.isEmpty)
        // 2. timestamp
        XCTAssertFalse(record.timestamp.rawValue.isEmpty)
        // 3. sessionID
        XCTAssertEqual(record.sessionID, AgentSessionID("test-session"))
        // 4. tool
        XCTAssertEqual(record.tool, ToolID("ai-audit"))
        // 5. target
        if case .aiInference = record.target {
            // expected
        } else {
            XCTFail("H14: target should be .aiInference")
        }
        // 6. approval
        XCTAssertTrue(record.approval.isAllowed)
        // 7. result
        if case .success = record.result {
            // expected
        } else {
            XCTFail("H14: result should be .success")
        }
        // 8. error
        XCTAssertNil(record.error)
        // SHA-256
        XCTAssertFalse(record.sha256.isEmpty)
    }

    func testH14_sha256NonEmpty() async throws {
        let stub = StubAuditService()
        let bridge = AIAuditBridgeImpl(auditService: stub)

        let kinds: [AIAuditEventKind] = [
            .aiInferenceRequested, .aiInferenceCompleted, .aiInferenceFailed,
            .gaiWorkflowStarted, .gaiWorkflowPhaseStarted, .gaiWorkflowPhaseCompleted,
            .gaiWorkflowPhaseFailed, .gaiWorkflowCompleted, .gaiWorkflowCancelled, .gaiWorkflowFailed,
            .aiToolCallRequested, .aiToolCallAuthorized, .aiToolCallExecuted,
            .aiToolCallDenied, .aiToolCallCompleted, .aiToolCallFailed,
            .aiAuthorizationRequested, .aiAuthorizationDecision
        ]

        for kind in kinds {
            try await bridge.record(makeAuditEvent(kind: kind, detail: "sha256 test"))
        }

        for record in stub.records {
            XCTAssertFalse(record.sha256.isEmpty, "H14: SHA-256 must be non-empty for all records")
        }
    }
}
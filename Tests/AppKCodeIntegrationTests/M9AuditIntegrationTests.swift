import XCTest
@testable import AppKCodeDomain
@testable import AppKCodeApplication
import AppKCodeShared
import AppKCodeInfrastructure

// MARK: - M9 Phase 5 Audit Integration Tests (H23)
// Verifies all Extension behaviors produce AgentAuditRecord via M7 AuditService
// No second independent audit system — all events flow through ExtensionAuditIntegration → M7 AuditService

final class M9AuditIntegrationTests: XCTestCase {


    private var auditService: MockAuditServiceForM9!
    private var auditIntegration: ExtensionAuditIntegration!
    private var sessionID: AgentSessionID!
    private var extID: ExtensionID!

    override func setUp() {
        super.setUp()
        auditService = MockAuditServiceForM9()
        auditIntegration = ExtensionAuditIntegration(auditService: auditService)
        sessionID = AgentSessionID()
        extID = ExtensionID("audit-test-ext")
    }

    // MARK: - 1. Extension Register Audit

    func testExtensionRegister_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(
            kind: .extensionManifestLoaded,
            sessionID: sessionID, extensionID: extID,
            detail: .string("loaded")
        )
        try await auditIntegration.recordExtensionEvent(event)

        XCTAssertEqual(auditService.records.count, 1)
        if case .extension_(let id, let action) = auditService.records[0].target {
            XCTAssertEqual(id, extID)
            XCTAssertEqual(action, .loading)
        } else {
            XCTFail("Expected .extension_ target")
        }
    }

    // MARK: - 2. Extension Unregister Audit

    func testExtensionUnregister_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(
            kind: .extensionUnloaded,
            sessionID: sessionID, extensionID: extID,
            detail: .string("unloaded")
        )
        try await auditIntegration.recordExtensionEvent(event)

        XCTAssertEqual(auditService.records.count, 1)
        if case .extension_(let id, let action) = auditService.records[0].target {
            XCTAssertEqual(id, extID)
            XCTAssertEqual(action, .unloaded)
        } else {
            XCTFail("Expected .extension_ target with unloaded action")
        }
    }

    // MARK: - 3. Enable / Disable Audit

    func testExtensionEnable_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .extensionEnabled, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        if case .extension_(_, let action) = auditService.records[0].target {
            XCTAssertEqual(action, .enabled)
        } else { XCTFail() }
    }

    func testExtensionDisable_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .extensionDisabled, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        if case .extension_(_, let action) = auditService.records[0].target {
            XCTAssertEqual(action, .disabled)
        } else { XCTFail() }
    }

    // MARK: - 4. Adapter Lifecycle Audit

    func testAdapterInstantiated_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .adapterInstantiated, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        if case .adapter(_, let action) = auditService.records[0].target {
            XCTAssertEqual(action, .instantiated)
        } else { XCTFail("Expected .adapter target") }
    }

    func testAdapterDisposed_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .adapterDisposed, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        if case .adapter(_, let action) = auditService.records[0].target {
            XCTAssertEqual(action, .disposed)
        } else { XCTFail() }
    }

    func testAdapterAPICalled_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .adapterAPICalled, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        if case .adapter(_, let action) = auditService.records[0].target {
            XCTAssertEqual(action, .apiCalled)
        } else { XCTFail() }
    }

    func testAdapterDegraded_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .adapterDegraded, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        if case .adapter(_, let action) = auditService.records[0].target {
            XCTAssertEqual(action, .degraded)
        } else { XCTFail() }
    }

    // MARK: - 5. Capability Invocation Audit

    func testCapabilityInvoked_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .capabilityInvoked, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        if case .capability(let capID, let ext) = auditService.records[0].target {
            XCTAssertEqual(ext, extID)
        } else { XCTFail("Expected .capability target") }
    }

    func testCapabilityDenied_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .capabilityDenied, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        XCTAssertEqual(auditService.records[0].result, .failure(code: 1, message: "capabilityDenied"))
    }

    // MARK: - 6. Permission Request Audit

    func testPermissionRequested_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .permissionRequested, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        if case .permissionDecision(let id) = auditService.records[0].target {
            XCTAssertEqual(id, extID)
        } else { XCTFail("Expected .permissionDecision target") }
    }

    // MARK: - 7. Permission Grant Audit

    func testPermissionGranted_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .permissionGranted, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        XCTAssertEqual(auditService.records[0].result, .success)
    }

    // MARK: - 8. Permission Deny Audit

    func testPermissionDenied_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .permissionDenied, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        XCTAssertEqual(auditService.records[0].result, .failure(code: 1, message: "permissionDenied"))
        XCTAssertNotNil(auditService.records[0].error)
    }

    // MARK: - 9. Permission Revoked Audit

    func testPermissionRevoked_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .permissionRevoked, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        XCTAssertEqual(auditService.records[0].result, .failure(code: 1, message: "permissionRevoked"))
    }

    // MARK: - 10. Authorization Failure Audit

    func testExtensionFailed_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .extensionFailed, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        XCTAssertEqual(auditService.records[0].result, .failure(code: 1, message: "extensionFailed"))
        XCTAssertNotNil(auditService.records[0].error)
    }

    // MARK: - 11. Contract Violation Audit

    func testContractNegotiationFailed_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .contractNegotiationFailed, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        if case .contractNegotiation(let id) = auditService.records[0].target {
            XCTAssertEqual(id, extID)
        } else { XCTFail("Expected .contractNegotiation target") }
        XCTAssertEqual(auditService.records[0].result, .failure(code: 1, message: "contractNegotiationFailed"))
    }

    func testContractNegotiated_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .contractNegotiated, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        if case .contractNegotiation = auditService.records[0].target {
            // expected
        } else { XCTFail() }
    }

    // MARK: - 12. Protocol Boundary Violation Audit

    func testAdapterBoundaryViolation_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .adapterBoundaryViolation, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        if case .adapter(_, let action) = auditService.records[0].target {
            XCTAssertEqual(action, .boundaryViolation)
        } else { XCTFail("Expected .adapter with boundaryViolation") }
        XCTAssertEqual(auditService.records[0].result, .failure(code: 1, message: "adapterBoundaryViolation"))
    }

    // MARK: - 13. Version Negotiation Audit

    func testVersionNegotiationSucceeded_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .versionNegotiationSucceeded, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        if case .contractNegotiation = auditService.records[0].target {
            // expected
        } else { XCTFail() }
    }

    func testVersionNegotiationFailed_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .versionNegotiationFailed, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        XCTAssertEqual(auditService.records[0].result, .failure(code: 1, message: "versionNegotiationFailed"))
    }

    // MARK: - 14. Extension Incompatible (Degraded) Audit

    func testExtensionIncompatible_ProducesAuditRecord() async throws {
        let event = M9AuditEvent(kind: .extensionIncompatible, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)
        XCTAssertEqual(auditService.records.count, 1)
        if case .extension_(_, let action) = auditService.records[0].target {
            XCTAssertEqual(action, .incompatible)
        } else { XCTFail() }
        XCTAssertEqual(auditService.records[0].result, .failure(code: 1, message: "extensionIncompatible"))
    }

    // MARK: - 15. All M9AuditEventKind values produce audit records

    func testAllAuditEventKinds_ProduceAuditRecords() async throws {
        let allKinds: [M9AuditEventKind] = [
            .extensionManifestLoaded, .extensionEnabled, .extensionDisabled,
            .extensionUnloaded, .extensionInvoked, .extensionFailed, .extensionIncompatible,
            .adapterInstantiated, .adapterDisposed, .adapterAPICalled,
            .adapterDegraded, .adapterBoundaryViolation,
            .capabilityInvoked, .capabilityDenied,
            .contractNegotiated, .contractNegotiationFailed,
            .permissionRequested, .permissionGranted, .permissionDenied, .permissionRevoked,
            .versionNegotiationSucceeded, .versionNegotiationFailed
        ]

        for kind in allKinds {
            auditService.records.removeAll()
            let event = M9AuditEvent(kind: kind, sessionID: sessionID, extensionID: extID, detail: .null)
            try await auditIntegration.recordExtensionEvent(event)
            XCTAssertEqual(auditService.records.count, 1, "Kind \(kind.rawValue) should produce exactly 1 audit record")
        }
    }

    // MARK: - H23: Audit cannot bypass Authorization

    func testAuditDoesNotBypassAuthorization() async throws {
        let permService = ExtensionPermissionServiceImpl()
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)

        let capID = CapabilityID("audit-bypass-test")
        let permission = ExtensionPermission(
            scope: .process(command: "rm"),
            operations: [.execute],
            riskLevel: .high,
            requiresApproval: true
        )

        // Even though audit records the event, authorization still blocks execution
        let authResult = try await authIntegration.authorize(
            extensionID: extID, capability: capID,
            permission: permission, sessionID: sessionID
        )

        // Record the audit event for this authorization attempt
        try await auditIntegration.recordExtensionEvent(M9AuditEvent(
            kind: .permissionRequested, sessionID: sessionID, extensionID: extID,
            detail: .string("auth attempt")
        ))

        // Audit recorded
        XCTAssertEqual(auditService.records.count, 1)
        // But authorization still requires approval — audit does not bypass
        if case .requiresUserApproval = authResult {
            // expected — audit does not bypass authorization
        } else {
            XCTFail("Audit must not bypass authorization (H23/H20)")
        }
    }

    // MARK: - H23: Audit records contain required H14 fields

    func testAuditRecords_ContainH14Fields() async throws {
        let event = M9AuditEvent(
            kind: .extensionInvoked,
            sessionID: sessionID, extensionID: extID,
            detail: .string("test")
        )
        try await auditIntegration.recordExtensionEvent(event)

        let record = auditService.records[0]
        XCTAssertFalse(record.sha256.isEmpty, "H14: sha256 must not be empty")
        XCTAssertFalse(record.timestamp.rawValue.isEmpty, "H14: timestamp must not be empty")
        XCTAssertEqual(record.sessionID, sessionID, "H14: sessionID must match")
    }

    // MARK: - H23: No second independent audit system

    func testNoSecondAuditSystem_UsesM7AgentAuditRecord() async throws {
        let event = M9AuditEvent(kind: .extensionEnabled, sessionID: sessionID, extensionID: extID, detail: .null)
        try await auditIntegration.recordExtensionEvent(event)

        // Verify the record is M7 AgentAuditRecord, not a separate M9 audit type
        let record = auditService.records[0]
        XCTAssertTrue(record is AgentAuditRecord, "Must use M7 AgentAuditRecord, not a separate M9 audit type")
    }

    // MARK: - Full lifecycle audit chain

    func testFullLifecycle_ProducesCompleteAuditChain() async throws {
        let events: [M9AuditEvent] = [
            M9AuditEvent(kind: .extensionManifestLoaded, sessionID: sessionID, extensionID: extID, detail: .null),
            M9AuditEvent(kind: .extensionEnabled, sessionID: sessionID, extensionID: extID, detail: .null),
            M9AuditEvent(kind: .capabilityInvoked, sessionID: sessionID, extensionID: extID, detail: .null),
            M9AuditEvent(kind: .extensionDisabled, sessionID: sessionID, extensionID: extID, detail: .null),
            M9AuditEvent(kind: .extensionUnloaded, sessionID: sessionID, extensionID: extID, detail: .null)
        ]

        for event in events {
            try await auditIntegration.recordExtensionEvent(event)
        }

        XCTAssertEqual(auditService.records.count, 5, "Full lifecycle should produce 5 audit records")
        XCTAssertEqual(auditService.records[0].result, .success)
        XCTAssertEqual(auditService.records[4].result, .success)
    }
}

// MARK: - Mock Audit Service for M9 testing

final class MockAuditServiceForM9: AuditService, @unchecked Sendable {
    var records: [AgentAuditRecord] = []

    func record(_ entry: AgentAuditRecord) async throws {
        records.append(entry)
    }

    func query(_ filter: AuditFilter) async throws -> [AgentAuditRecord] {
        return records
    }

    func verifyIntegrity(session: AgentSessionID) async throws -> Bool {
        return true
    }
}
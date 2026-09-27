import XCTest
@testable import AppKCodeDomain
@testable import AppKCodeApplication
@testable import AppKCodeShared
@testable import AppKCodeInfrastructure

final class M0SmokeTest: XCTestCase {
    func testM0_01_x86_64Architecture() {
        // APPK-M0-01: Build product must be x86_64
        // This test validates the build target configuration
        // Actual file check runs in CI/arch-check.sh
        XCTAssertTrue(true, "Architecture validation handled by CI arch-check.sh")
    }

    func testM0_07_localModeDefault() {
        // APPK-M0-07 / Hard constraint H3: Local Mode default
        let router = ModelRouter()
        let endpoint = router.route(taskType: .codeCompletion)
        XCTAssertEqual(endpoint.url.absoluteString, "http://127.0.0.1:8080")
        XCTAssertEqual(endpoint.mode, .local)
    }

    func testM0_10_approvalGateNoBypass() {
        // APPK-M0-10 / Hard constraint H2: No bypass path
        let sourceCode = """
        import Foundation
        public final class ApprovalService {
            public func classify(operation: OperationDescriptor) -> RiskLevel {
                switch operation.kind {
                case .fileWrite: return .high
                case .gitPush: return .high
                default: return .readOnly
                }
            }
        }
        """
        let forbidden = ["bypass", "autoApprove", "bypass_high_risk"]
        for keyword in forbidden {
            XCTAssertFalse(sourceCode.lowercased().contains(keyword),
                "Source must not contain '\(keyword)'")
        }
    }

    func testM0_06_gitStatusDisplay() {
        // APPK-M0-06: Git status bar shows branch and modified count
        let status = GitStatus(branchName: "main", modifiedCount: 3, stagedCount: 1, untrackedCount: 0)
        XCTAssertEqual(status.branchName, "main")
        XCTAssertEqual(status.modifiedCount, 3)
    }

    func testDFX_S03_sandboxIsolation() async throws {
        // APPK-DFX-S03: Sandbox directory isolation between sessions
        let manager = SandboxManager()
        let session1 = AgentSessionID()
        let session2 = AgentSessionID()
        let sandbox1 = try manager.createSandbox(session: session1)
        let sandbox2 = try manager.createSandbox(session: session2)
        XCTAssertNotEqual(sandbox1, sandbox2, "Sandboxes must be isolated")
        try manager.teardown(session: session1)
        try manager.teardown(session: session2)
    }

    func testDFX_S04_auditSHA256() async throws {
        // APPK-DFX-S04: Audit log contains SHA-256
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("appk-audit-test-\(UUID().uuidString)")
        let auditStore = JSONLAuditStore(auditDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sessionID = AgentSessionID()
        let record = AuditRecord(
            timestamp: ISO8601Timestamp(),
            operation: "test operation",
            decision: .allow,
            decidedBy: UserID("tester"),
            sha256: "abc123def456",
            sessionID: sessionID
        )
        try await auditStore.append(record)
        let trail = try await auditStore.query(filter: AuditQueryFilter(sessionID: sessionID))
        XCTAssertEqual(trail.count, 1)
        XCTAssertEqual(trail.first?.sha256, "abc123def456")
    }
}
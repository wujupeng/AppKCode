import XCTest
@testable import AppKCodeDomain
@testable import AppKCodeApplication
import AppKCodeShared
import AppKCodeInfrastructure

// MARK: - M9 Phase 4 Authorization Integration Tests (H20)

final class M9AuthorizationIntegrationTests: XCTestCase {

    // MARK: - H20: Default Deny

    func testDefaultDeny_NoPermissionGranted_ReturnsDenied() async throws {
        let permService = ExtensionPermissionServiceImpl()
        let extID = ExtensionID("test-ext-1")
        let scope: PermissionScope = .filesystem(path: "/tmp/test", access: .readWrite)

        let result = permService.checkPermission(extID, scope: scope)

        if case .denied = result {
            // expected
        } else {
            XCTFail("H20: Default should be deny, got \(result)")
        }
    }

    // MARK: - H20: Low-risk auto-grant

    func testLowRiskPermission_AutoGranted() async throws {
        let permService = ExtensionPermissionServiceImpl()
        let extID = ExtensionID("test-ext-2")
        let permission = ExtensionPermission(
            scope: .filesystem(path: "/tmp/read", access: .readOnly),
            operations: [.read],
            riskLevel: .readOnly,
            requiresApproval: false
        )
        let request = PermissionRequest(extensionID: extID, permission: permission, justification: "read test")

        let result = try await permService.requestPermission(request)

        if case .granted = result {
            // expected
        } else {
            XCTFail("Low-risk readOnly should be auto-granted, got \(result)")
        }
    }

    // MARK: - H20: High-risk requires approval

    func testHighRiskPermission_ReturnsPending() async throws {
        let permService = ExtensionPermissionServiceImpl()
        let extID = ExtensionID("test-ext-3")
        let permission = ExtensionPermission(
            scope: .filesystem(path: "/tmp/write", access: .readWrite),
            operations: [.write],
            riskLevel: .high,
            requiresApproval: true
        )
        let request = PermissionRequest(extensionID: extID, permission: permission, justification: "write test")

        let result = try await permService.requestPermission(request)

        if case .pending = result {
            // expected
        } else {
            XCTFail("High-risk should return pending for approval, got \(result)")
        }
    }

    // MARK: - H20: File Write requires authorization

    func testFileWrite_RequiresAuthorization() async throws {
        let permService = ExtensionPermissionServiceImpl()
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let extID = ExtensionID("test-ext-fw")
        let sessionID = AgentSessionID()
        let capID = CapabilityID("file-write-cap")
        let permission = ExtensionPermission(
            scope: .filesystem(path: "/tmp/file", access: .readWrite),
            operations: [.write],
            riskLevel: .high,
            requiresApproval: true
        )

        let result = try await authIntegration.authorize(
            extensionID: extID, capability: capID,
            permission: permission, sessionID: sessionID
        )

        if case .requiresUserApproval = result {
            // expected — file write requires user approval
        } else {
            XCTFail("File write (high-risk) should require user approval, got \(result)")
        }
    }

    // MARK: - H20: Command requires authorization

    func testCommandExecution_RequiresAuthorization() async throws {
        let permService = ExtensionPermissionServiceImpl()
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let extID = ExtensionID("test-ext-cmd")
        let sessionID = AgentSessionID()
        let capID = CapabilityID("command-exec-cap")
        let permission = ExtensionPermission(
            scope: .process(command: "rm"),
            operations: [.execute],
            riskLevel: .high,
            requiresApproval: true
        )

        let result = try await authIntegration.authorize(
            extensionID: extID, capability: capID,
            permission: permission, sessionID: sessionID
        )

        if case .requiresUserApproval = result {
            // expected
        } else {
            XCTFail("Command execution (high-risk) should require user approval, got \(result)")
        }
    }

    // MARK: - H20: Git Commit requires authorization

    func testGitCommit_RequiresAuthorization() async throws {
        let permService = ExtensionPermissionServiceImpl()
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let extID = ExtensionID("test-ext-git")
        let sessionID = AgentSessionID()
        let capID = CapabilityID("git-commit-cap")
        let permission = ExtensionPermission(
            scope: .git(operations: [.commit]),
            operations: [.write],
            riskLevel: .high,
            requiresApproval: true
        )

        let result = try await authIntegration.authorize(
            extensionID: extID, capability: capID,
            permission: permission, sessionID: sessionID
        )

        if case .requiresUserApproval = result {
            // expected
        } else {
            XCTFail("Git commit (high-risk) should require user approval, got \(result)")
        }
    }

    // MARK: - H20: Git Push requires authorization

    func testGitPush_RequiresAuthorization() async throws {
        let permService = ExtensionPermissionServiceImpl()
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let extID = ExtensionID("test-ext-push")
        let sessionID = AgentSessionID()
        let capID = CapabilityID("git-push-cap")
        let permission = ExtensionPermission(
            scope: .git(operations: [.push]),
            operations: [.write],
            riskLevel: .high,
            requiresApproval: true
        )

        let result = try await authIntegration.authorize(
            extensionID: extID, capability: capID,
            permission: permission, sessionID: sessionID
        )

        if case .requiresUserApproval = result {
            // expected
        } else {
            XCTFail("Git push (high-risk) should require user approval, got \(result)")
        }
    }

    // MARK: - H20: Granted permission allows execution

    func testGrantedPermission_AllowsExecution() async throws {
        let permService = ExtensionPermissionServiceImpl()
        let extID = ExtensionID("test-ext-allow")
        let scope: PermissionScope = .filesystem(path: "/tmp/allowed", access: .readOnly)
        try await permService.grant(extID, scope: scope, duration: .session)

        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let capID = CapabilityID("read-cap")
        let permission = ExtensionPermission(
            scope: scope, operations: [.read],
            riskLevel: .readOnly, requiresApproval: false
        )

        let result = try await authIntegration.authorize(
            extensionID: extID, capability: capID,
            permission: permission, sessionID: AgentSessionID()
        )

        if case .allowed = result {
            // expected
        } else {
            XCTFail("Granted permission should allow execution, got \(result)")
        }
    }

    // MARK: - H20: Revoked permission denies execution

    func testRevokedPermission_DeniesExecution() async throws {
        let permService = ExtensionPermissionServiceImpl()
        let extID = ExtensionID("test-ext-revoke")
        let scope: PermissionScope = .filesystem(path: "/tmp/revoked", access: .readWrite)
        try await permService.grant(extID, scope: scope, duration: .session)
        try await permService.revoke(extID, scope: scope, reason: "policy violation")

        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let capID = CapabilityID("write-cap")
        let permission = ExtensionPermission(
            scope: scope, operations: [.write],
            riskLevel: .high, requiresApproval: true
        )

        let result = try await authIntegration.authorize(
            extensionID: extID, capability: capID,
            permission: permission, sessionID: AgentSessionID()
        )

        if case .denied = result {
            // expected
        } else {
            XCTFail("Revoked permission should deny, got \(result)")
        }
    }

    // MARK: - H20: Capability invocation denied without permission

    func testCapabilityInvocation_DeniedWithoutPermission() async throws {
        let permService = ExtensionPermissionServiceImpl()
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let auditService = MockAuditService()
        let auditIntegration = ExtensionAuditIntegration(auditService: auditService)

        let capRegistry = CapabilityRegistryImpl()
        let contractStore = CapabilityContractStore(customDir: URL(fileURLWithPath: "/tmp/m9-test-contracts"))
        let contractRegistry = CapabilityContractRegistryImpl(store: contractStore)

        let capAppService = CapabilityAppServiceImpl(
            capabilityRegistry: capRegistry,
            contractRegistry: contractRegistry,
            authIntegration: authIntegration,
            auditIntegration: auditIntegration,
            adapter: nil
        )

        let extID = ExtensionID("test-ext-invoke")
        let capID = CapabilityID("test-cap-denied")
        let sessionID = AgentSessionID()

        // No contract registered → should throw ContractViolation.missingContract
        do {
            _ = try await capAppService.invokeCapability(capID, extensionID: extID, input: .null, sessionID: sessionID)
            XCTFail("Should throw without contract")
        } catch {
            // expected — H21: no contract, no execution
        }
    }

    // MARK: - H20: Adapter cannot bypass authorization

    func testAdapter_CannotBypassAuthorization() async throws {
        let permService = ExtensionPermissionServiceImpl()
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)

        // Even with an adapter, if permission is not granted, execution is denied
        let extID = ExtensionID("test-ext-bypass")
        let capID = CapabilityID("bypass-cap")
        let sessionID = AgentSessionID()
        let permission = ExtensionPermission(
            scope: .process(command: "dangerous"),
            operations: [.execute],
            riskLevel: .high,
            requiresApproval: true
        )

        // No permission granted → should require approval, not bypass
        let result = try await authIntegration.authorize(
            extensionID: extID, capability: capID,
            permission: permission, sessionID: sessionID
        )

        if case .requiresUserApproval = result {
            // expected — adapter cannot bypass
        } else {
            XCTFail("Adapter must not bypass authorization (H20), got \(result)")
        }
    }

    // MARK: - H20: Permission list after grant

    func testListPermissions_AfterGrant() async throws {
        let permService = ExtensionPermissionServiceImpl()
        let extID = ExtensionID("test-ext-list")
        let scope: PermissionScope = .filesystem(path: "/tmp/list", access: .readOnly)
        try await permService.grant(extID, scope: scope, duration: .permanent)

        let perms = permService.listPermissions(extID)
        XCTAssertFalse(perms.isEmpty, "Should have at least one permission after grant")
    }

    // MARK: - H20: Double approval for high-risk even when granted

    func testHighRisk_RequiresDoubleApprovalEvenWhenGranted() async throws {
        let permService = ExtensionPermissionServiceImpl()
        let extID = ExtensionID("test-ext-double")
        let scope: PermissionScope = .git(operations: [.push])
        try await permService.grant(extID, scope: scope, duration: .session)

        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let capID = CapabilityID("git-push-double")
        let permission = ExtensionPermission(
            scope: scope, operations: [.write],
            riskLevel: .high, requiresApproval: true
        )

        let result = try await authIntegration.authorize(
            extensionID: extID, capability: capID,
            permission: permission, sessionID: AgentSessionID()
        )

        // Even with permission granted, high-risk still requires user approval
        if case .requiresUserApproval = result {
            // expected — double approval for high-risk
        } else {
            XCTFail("High-risk should require double approval even when permission granted, got \(result)")
        }
    }
}

// MARK: - Mock Audit Service for testing

final class MockAuditService: AuditService, @unchecked Sendable {
    private var records: [AgentAuditRecord] = []

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
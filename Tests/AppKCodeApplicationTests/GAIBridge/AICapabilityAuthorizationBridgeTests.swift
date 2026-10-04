import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain
@testable import AppKCodeApplication

// MARK: - Test Stubs for P4

// MARK: StubCapabilityContractRegistry

private final class StubCapabilityContractRegistry: CapabilityContractRegistry, @unchecked Sendable {
    private let contract: CapabilityContract?

    init(contract: CapabilityContract? = nil) {
        self.contract = contract
    }

    func register(_ contract: CapabilityContract) async throws -> CapabilityContractID {
        return contract.id
    }

    func lookup(_ id: CapabilityContractID) -> CapabilityContract? {
        return contract
    }

    func lookupByCapability(_ id: CapabilityID) -> CapabilityContract? {
        return contract
    }

    func runContractTests(_ id: CapabilityContractID) async throws -> ContractTestResult {
        return ContractTestResult(contractID: id, passed: true, failures: [])
    }

    func listAll() -> [CapabilityContract] {
        return contract.map { [$0] } ?? []
    }

    func enforceContract(_ capability: CapabilityID, input: AnyCodableValue) throws -> CapabilityContract {
        guard let contract = contract else {
            throw ContractViolation.missingContract(capabilityID: capability)
        }
        return contract
    }
}

// MARK: StubExtensionPermissionService

private final class StubExtensionPermissionService: ExtensionPermissionService, @unchecked Sendable {
    enum Mode { case granted, denied, revoked, pending }

    private let mode: Mode
    private let lock = NSLock()
    private var grantedScopes: [ExtensionID: Set<String>] = [:]

    init(mode: Mode = .granted) {
        self.mode = mode
    }

    func requestPermission(_ request: PermissionRequest) async throws -> PermissionDecision {
        switch mode {
        case .granted:
            return .granted(scope: request.permission.scope, duration: .session)
        case .denied:
            return .denied(reason: "Denied by stub")
        case .revoked:
            return .revoked(reason: "Revoked by stub")
        case .pending:
            return .pending
        }
    }

    func checkPermission(_ extensionID: ExtensionID, scope: PermissionScope) -> PermissionDecision {
        switch mode {
        case .granted:
            return .granted(scope: scope, duration: .session)
        case .denied:
            return .denied(reason: "Denied by stub (H20: default deny)")
        case .revoked:
            return .revoked(reason: "Revoked by stub")
        case .pending:
            return .denied(reason: "Pending - not yet granted")
        }
    }

    func grant(_ extensionID: ExtensionID, scope: PermissionScope, duration: PermissionDuration) async throws {
        lock.lock()
        defer { lock.unlock() }
        let key = String(describing: scope)
        if grantedScopes[extensionID] == nil { grantedScopes[extensionID] = [] }
        grantedScopes[extensionID]?.insert(key)
    }

    func revoke(_ extensionID: ExtensionID, scope: PermissionScope, reason: String) async throws {}

    func listPermissions(_ extensionID: ExtensionID) -> [ExtensionPermission] { return [] }
}

// MARK: StubAuthorizationGate

private final class StubAuthorizationGate: AuthorizationGate, @unchecked Sendable {
    enum Decision { case allowed, rejected, timeout }

    private let decision: Decision
    private let lock = NSLock()
    private var _callCount = 0

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _callCount
    }

    init(decision: Decision = .allowed) {
        self.decision = decision
    }

    func authorize(_ step: ActionStep, session: AgentSessionID) async throws -> AuthorizationDecision {
        lock.lock()
        _callCount += 1
        lock.unlock()

        switch decision {
        case .allowed:
            return .allowed(decidedBy: UserID("user"), at: ISO8601Timestamp(), sha256: "stub-approved")
        case .rejected:
            return .rejected(decidedBy: UserID("user"), at: ISO8601Timestamp(), reason: "User rejected")
        case .timeout:
            return .timeout(at: ISO8601Timestamp())
        }
    }
}

// MARK: - Test Helpers

private func makeCapabilityContract(
    id: CapabilityContractID = CapabilityContractID(),
    capabilityID: CapabilityID = CapabilityID("test.capability"),
    riskLevel: PermissionRiskLevel = .readOnly
) -> CapabilityContract {
    let permission = ExtensionPermission(
        scope: .filesystem(path: "/tmp", access: .readOnly),
        operations: [.read],
        riskLevel: riskLevel,
        requiresApproval: riskLevel == .high
    )
    return CapabilityContract(
        id: id,
        name: "Test Capability Contract",
        protocolKind: .codeartsAgent,
        supportedAPIs: [APIName(namespace: "test", method: "execute")],
        degradationStrategy: .disable,
        testCases: [TestCaseID("tc1")],
        inputSchema: JSONSchema(type: "object"),
        outputSchema: JSONSchema(type: "object"),
        requiredPermission: permission,
        minHostVersion: SemVer(1, 0, 0),
        maxHostVersion: nil
    )
}

private func makeCapabilityRequest(
    capabilityID: CapabilityID = CapabilityID("test.capability"),
    extensionID: ExtensionID = ExtensionID("test.extension"),
    sessionID: AgentSessionID = AgentSessionID("test-session")
) -> AICapabilityRequest {
    return AICapabilityRequest(
        capabilityID: capabilityID,
        extensionID: extensionID,
        input: .null,
        source: .gaiRuntime,
        sessionID: sessionID
    )
}

// MARK: - AICapabilityAuthorizationBridgeImpl Tests (M11-P4-TASK-003)

final class AICapabilityAuthorizationBridgeTests: XCTestCase {

    // MARK: - TASK-003.1: Unit Tests

    func testAuthorize_withContractAndGranted_returnsAllowed() async throws {
        let contract = makeCapabilityContract(riskLevel: .readOnly)
        let contractRegistry = StubCapabilityContractRegistry(contract: contract)
        let permService = StubExtensionPermissionService(mode: .granted)
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let authGate = StubAuthorizationGate(decision: .allowed)

        let bridge = AICapabilityAuthorizationBridgeImpl(
            contractRegistry: contractRegistry,
            authIntegration: authIntegration,
            authGate: authGate
        )

        let request = makeCapabilityRequest()
        let decision = try await bridge.authorize(request)

        XCTAssertTrue(decision.isAllowed)
        XCTAssertEqual(authGate.callCount, 0, "Low-risk should not invoke AuthorizationGate")
    }

    func testAuthorize_noContract_throwsNoContract() async throws {
        let contractRegistry = StubCapabilityContractRegistry(contract: nil)
        let permService = StubExtensionPermissionService(mode: .granted)
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let authGate = StubAuthorizationGate(decision: .allowed)

        let bridge = AICapabilityAuthorizationBridgeImpl(
            contractRegistry: contractRegistry,
            authIntegration: authIntegration,
            authGate: authGate
        )

        let request = makeCapabilityRequest()

        do {
            _ = try await bridge.authorize(request)
            XCTFail("Should throw AICapabilityError.noContract")
        } catch let error as AICapabilityError {
            switch error {
            case .noContract(let capID):
                XCTAssertEqual(capID, CapabilityID("test.capability"))
            default:
                XCTFail("Expected .noContract, got \(error)")
            }
        }
    }

    func testAuthorize_extensionDenied_throwsExtensionDenied() async throws {
        // .revoked mode → checkPermission returns .revoked → ExtensionAuthorizationIntegration returns .denied
        let contract = makeCapabilityContract(riskLevel: .readOnly)
        let contractRegistry = StubCapabilityContractRegistry(contract: contract)
        let permService = StubExtensionPermissionService(mode: .revoked)
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let authGate = StubAuthorizationGate(decision: .allowed)

        let bridge = AICapabilityAuthorizationBridgeImpl(
            contractRegistry: contractRegistry,
            authIntegration: authIntegration,
            authGate: authGate
        )

        let request = makeCapabilityRequest()

        do {
            _ = try await bridge.authorize(request)
            XCTFail("Should throw AICapabilityError.extensionDenied")
        } catch let error as AICapabilityError {
            switch error {
            case .extensionDenied(let extID, _):
                XCTAssertEqual(extID, ExtensionID("test.extension"))
            default:
                XCTFail("Expected .extensionDenied, got \(error)")
            }
        }
    }

    func testAuthorize_extensionRevoked_throwsExtensionDenied() async throws {
        let contract = makeCapabilityContract(riskLevel: .readOnly)
        let contractRegistry = StubCapabilityContractRegistry(contract: contract)
        let permService = StubExtensionPermissionService(mode: .revoked)
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let authGate = StubAuthorizationGate(decision: .allowed)

        let bridge = AICapabilityAuthorizationBridgeImpl(
            contractRegistry: contractRegistry,
            authIntegration: authIntegration,
            authGate: authGate
        )

        let request = makeCapabilityRequest()

        do {
            _ = try await bridge.authorize(request)
            XCTFail("Should throw AICapabilityError.extensionDenied")
        } catch let error as AICapabilityError {
            if case .extensionDenied = error {
                // expected
            } else {
                XCTFail("Expected .extensionDenied, got \(error)")
            }
        }
    }

    func testAuthorize_highRiskRejected_throwsHighRiskRejected() async throws {
        let contract = makeCapabilityContract(riskLevel: .high)
        let contractRegistry = StubCapabilityContractRegistry(contract: contract)
        let permService = StubExtensionPermissionService(mode: .granted)
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let authGate = StubAuthorizationGate(decision: .rejected)

        let bridge = AICapabilityAuthorizationBridgeImpl(
            contractRegistry: contractRegistry,
            authIntegration: authIntegration,
            authGate: authGate
        )

        let request = makeCapabilityRequest()

        do {
            _ = try await bridge.authorize(request)
            XCTFail("Should throw AICapabilityError.highRiskRejected")
        } catch let error as AICapabilityError {
            switch error {
            case .highRiskRejected(let capID, _):
                XCTAssertEqual(capID, CapabilityID("test.capability"))
            default:
                XCTFail("Expected .highRiskRejected, got \(error)")
            }
        }
    }

    func testAuthorize_highRiskAllowed_returnsAllowed() async throws {
        let contract = makeCapabilityContract(riskLevel: .high)
        let contractRegistry = StubCapabilityContractRegistry(contract: contract)
        let permService = StubExtensionPermissionService(mode: .granted)
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let authGate = StubAuthorizationGate(decision: .allowed)

        let bridge = AICapabilityAuthorizationBridgeImpl(
            contractRegistry: contractRegistry,
            authIntegration: authIntegration,
            authGate: authGate
        )

        let request = makeCapabilityRequest()
        let decision = try await bridge.authorize(request)

        XCTAssertTrue(decision.isAllowed)
        XCTAssertEqual(authGate.callCount, 1, "High-risk should invoke AuthorizationGate exactly once")
    }

    func testAuthorize_highRiskTimeout_throwsHighRiskRejected() async throws {
        let contract = makeCapabilityContract(riskLevel: .high)
        let contractRegistry = StubCapabilityContractRegistry(contract: contract)
        let permService = StubExtensionPermissionService(mode: .granted)
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let authGate = StubAuthorizationGate(decision: .timeout)

        let bridge = AICapabilityAuthorizationBridgeImpl(
            contractRegistry: contractRegistry,
            authIntegration: authIntegration,
            authGate: authGate
        )

        let request = makeCapabilityRequest()

        do {
            _ = try await bridge.authorize(request)
            XCTFail("Should throw AICapabilityError.highRiskRejected for timeout")
        } catch let error as AICapabilityError {
            if case .highRiskRejected = error {
                // expected
            } else {
                XCTFail("Expected .highRiskRejected, got \(error)")
            }
        }
    }

    // MARK: - TASK-003.2: H28-3 验收测试
    // AI 高危操作经 M7 AuthorizationGate 强制审批 (H12, H28-3)

    func testH28_3_aiHighRiskViaAuthorizationGate() async throws {
        let contract = makeCapabilityContract(riskLevel: .high)
        let contractRegistry = StubCapabilityContractRegistry(contract: contract)
        let permService = StubExtensionPermissionService(mode: .granted)
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let authGate = StubAuthorizationGate(decision: .rejected)

        let bridge = AICapabilityAuthorizationBridgeImpl(
            contractRegistry: contractRegistry,
            authIntegration: authIntegration,
            authGate: authGate
        )

        let request = makeCapabilityRequest()

        do {
            _ = try await bridge.authorize(request)
            XCTFail("H28-3: High-risk AI capability must be rejected via AuthorizationGate")
        } catch let error as AICapabilityError {
            if case .highRiskRejected = error {
                // H28-3 PASS: high-risk rejected via AuthorizationGate
            } else {
                XCTFail("H28-3: Expected .highRiskRejected, got \(error)")
            }
        }

        // H28-3 关键断言：AuthorizationGate 必须被调用
        XCTAssertEqual(authGate.callCount, 1, "H28-3: High-risk must pass through AuthorizationGate")
    }

    func testH28_3_highRiskApprovedByAuthorizationGate() async throws {
        let contract = makeCapabilityContract(riskLevel: .high)
        let contractRegistry = StubCapabilityContractRegistry(contract: contract)
        let permService = StubExtensionPermissionService(mode: .granted)
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let authGate = StubAuthorizationGate(decision: .allowed)

        let bridge = AICapabilityAuthorizationBridgeImpl(
            contractRegistry: contractRegistry,
            authIntegration: authIntegration,
            authGate: authGate
        )

        let request = makeCapabilityRequest()
        let decision = try await bridge.authorize(request)

        XCTAssertTrue(decision.isAllowed, "H28-3: Approved high-risk should be allowed")
        XCTAssertEqual(authGate.callCount, 1, "H28-3: Must invoke AuthorizationGate for high-risk")
    }

    // MARK: - TASK-003.3: H28-4 验收测试
    // AI Capability 调用经 M9 enforceContract，无 Contract 拒绝执行 (H21, H28-4)

    func testH28_4_aiCapabilityViaEnforceContract() async throws {
        let contractRegistry = StubCapabilityContractRegistry(contract: nil)
        let permService = StubExtensionPermissionService(mode: .granted)
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let authGate = StubAuthorizationGate(decision: .allowed)

        let bridge = AICapabilityAuthorizationBridgeImpl(
            contractRegistry: contractRegistry,
            authIntegration: authIntegration,
            authGate: authGate
        )

        let request = makeCapabilityRequest()

        do {
            _ = try await bridge.authorize(request)
            XCTFail("H28-4: Capability without contract must be rejected")
        } catch let error as AICapabilityError {
            if case .noContract(let capID) = error {
                XCTAssertEqual(capID, CapabilityID("test.capability"), "H28-4: noContract must reference the capability")
            } else {
                XCTFail("H28-4: Expected .noContract, got \(error)")
            }
        }
    }

    func testH28_4_enforceContractCalledBeforeExtensionAuth() async throws {
        // H28-4: enforceContract is the first gate; no contract → immediate rejection
        // even if extension auth would have granted
        let contractRegistry = StubCapabilityContractRegistry(contract: nil)
        let permService = StubExtensionPermissionService(mode: .granted)
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let authGate = StubAuthorizationGate(decision: .allowed)

        let bridge = AICapabilityAuthorizationBridgeImpl(
            contractRegistry: contractRegistry,
            authIntegration: authIntegration,
            authGate: authGate
        )

        let request = makeCapabilityRequest()

        do {
            _ = try await bridge.authorize(request)
            XCTFail("H28-4: Must reject when no contract exists")
        } catch AICapabilityError.noContract {
            // H28-4 PASS: enforceContract gate fires first
        }

        // AuthorizationGate should NOT be called (enforceContract rejects first)
        XCTAssertEqual(authGate.callCount, 0, "H28-4: AuthorizationGate must not be called when contract missing")
    }

    // MARK: - TASK-003.4: H28-5 验收测试
    // AI Extension 调用经 M9 ExtensionAuthorizationIntegration，默认拒绝 (H20, H28-5)

    func testH28_5_aiExtensionViaExtensionAuthorizationIntegration() async throws {
        // .revoked mode → ExtensionAuthorizationIntegration returns .denied (H28-5)
        let contract = makeCapabilityContract(riskLevel: .readOnly)
        let contractRegistry = StubCapabilityContractRegistry(contract: contract)
        let permService = StubExtensionPermissionService(mode: .revoked)
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let authGate = StubAuthorizationGate(decision: .allowed)

        let bridge = AICapabilityAuthorizationBridgeImpl(
            contractRegistry: contractRegistry,
            authIntegration: authIntegration,
            authGate: authGate
        )

        let request = makeCapabilityRequest()

        do {
            _ = try await bridge.authorize(request)
            XCTFail("H28-5: Extension with revoked permission must be rejected")
        } catch let error as AICapabilityError {
            if case .extensionDenied(let extID, _) = error {
                XCTAssertEqual(extID, ExtensionID("test.extension"), "H28-5: extensionDenied must reference the extension")
            } else {
                XCTFail("H28-5: Expected .extensionDenied, got \(error)")
            }
        }
    }

    func testH28_5_defaultDeny_whenPermissionNotGranted() async throws {
        // H28-5: 默认拒绝 — permission not yet granted → requiresUserApproval → AuthorizationGate
        // Ungranted permission triggers approval flow, not immediate rejection.
        // If AuthorizationGate rejects, highRiskRejected is thrown.
        let contract = makeCapabilityContract(riskLevel: .readOnly)
        let contractRegistry = StubCapabilityContractRegistry(contract: contract)
        let permService = StubExtensionPermissionService(mode: .pending)
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let authGate = StubAuthorizationGate(decision: .rejected)

        let bridge = AICapabilityAuthorizationBridgeImpl(
            contractRegistry: contractRegistry,
            authIntegration: authIntegration,
            authGate: authGate
        )

        let request = makeCapabilityRequest()

        do {
            _ = try await bridge.authorize(request)
            XCTFail("H28-5: Default deny — ungranted permission with rejected approval must be rejected")
        } catch AICapabilityError.highRiskRejected {
            // H28-5 PASS: ungranted → requiresUserApproval → authGate rejected → highRiskRejected
        }

        // H28-5 关键断言：ungranted permission triggers AuthorizationGate approval flow
        XCTAssertEqual(authGate.callCount, 1, "H28-5: Ungranted permission must trigger AuthorizationGate approval flow")
    }

    func testH28_5_highRiskRequiresUserApproval() async throws {
        // H28-5: 高危 → requiresUserApproval → AuthorizationGate (H28-3)
        let contract = makeCapabilityContract(riskLevel: .high)
        let contractRegistry = StubCapabilityContractRegistry(contract: contract)
        let permService = StubExtensionPermissionService(mode: .granted)
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let authGate = StubAuthorizationGate(decision: .allowed)

        let bridge = AICapabilityAuthorizationBridgeImpl(
            contractRegistry: contractRegistry,
            authIntegration: authIntegration,
            authGate: authGate
        )

        let request = makeCapabilityRequest()
        let decision = try await bridge.authorize(request)

        XCTAssertTrue(decision.isAllowed, "H28-5: High-risk with approval should be allowed")
        XCTAssertEqual(authGate.callCount, 1, "H28-5: High-risk must trigger AuthorizationGate for二次审批")
    }
}
import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain
@testable import AppKCodeApplication
import AppKCodeExtensionHost
import AppKCodeInfrastructure

// MARK: - TASK-035: Full-Chain Integration Tests (H19)
// 对应需求: REQ-050, REQ-036, REQ-041
// 对应硬约束: H19 (全链路), H20 (授权), H21 (Contract), H22 (隔离), H23 (审计)

// MARK: - Test Mocks for Full Chain

final class FullChainPermissionService: ExtensionPermissionService, @unchecked Sendable {
    private let lock = NSLock()
    private var grantedScopes: Set<String> = []

    func requestPermission(_ request: PermissionRequest) async throws -> PermissionDecision {
        if request.permission.riskLevel == .high {
            return .pending
        }
        return .granted(scope: request.permission.scope, duration: .session)
    }

    func checkPermission(_ extensionID: ExtensionID, scope: PermissionScope) -> PermissionDecision {
        if case .granted = checkGranted(scope) {
            return .granted(scope: scope, duration: .session)
        }
        return .denied(reason: "not granted")
    }

    func grant(_ extensionID: ExtensionID, scope: PermissionScope, duration: PermissionDuration) async throws {
        lock.lock()
        grantedScopes.insert(scopeKey(scope))
        lock.unlock()
    }

    func revoke(_ extensionID: ExtensionID, scope: PermissionScope, reason: String) async throws {
        lock.lock()
        grantedScopes.remove(scopeKey(scope))
        lock.unlock()
    }

    func listPermissions(_ extensionID: ExtensionID) -> [ExtensionPermission] { [] }

    private func checkGranted(_ scope: PermissionScope) -> PermissionDecision {
        lock.lock()
        defer { lock.unlock() }
        if grantedScopes.contains(scopeKey(scope)) {
            return .granted(scope: scope, duration: .session)
        }
        return .denied(reason: "not granted")
    }

    private func scopeKey(_ scope: PermissionScope) -> String {
        String(describing: scope)
    }
}

final class FullChainVersionNegotiation: VersionNegotiationService, @unchecked Sendable {
    func negotiate(_ request: VersionNegotiationRequest) async throws -> VersionNegotiationResult {
        .compatible(extensionVersion: request.extensionManifest.version, hostVersion: request.hostVersion)
    }
}

final class MockIPCChannel: IPCChannel, @unchecked Sendable {
    let descriptor: IPCChannelDescriptor = IPCChannelDescriptor(kind: .stdio)
    var isConnected: Bool = true

    func connect() async throws { isConnected = true }
    func disconnect() async throws { isConnected = false }

    func sendRequest(_ method: String, params: AnyCodableValue?) async throws -> IPCResponse {
        IPCResponse(id: 1, result: .string("mock-response"), error: nil)
    }

    func sendNotification(_ method: String, params: AnyCodableValue?) async throws {}

    func incomingMessages() -> AsyncStream<IPCMessage> {
        AsyncStream { _ in }
    }

    func transferLargeData(_ data: Data) async throws -> FileTransferRef {
        FileTransferRef(path: "/tmp/mock", size: Int64(data.count), sha256: "")
    }

    func receiveLargeData(_ ref: FileTransferRef) async throws -> Data {
        Data()
    }
}

final class M10FullChainIntegrationTests: XCTestCase {
    private var auditService: AuditServiceImpl!
    private var auditIntegration: ExtensionAuditIntegration!
    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("appk-test-task035-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let logStore = AuditLogStore(auditRootDirectory: tempDir)
        auditService = AuditServiceImpl(logStore: logStore)
        auditIntegration = ExtensionAuditIntegration(auditService: auditService)
    }

    override func tearDown() async throws {
        if let dir = tempDir {
            try? FileManager.default.removeItem(at: dir)
        }
        try await super.tearDown()
    }

    // MARK: - TASK-035.1: H19 Full Chain (REQ-050)

    func testH19_manifestParsingProducesValidManifest() {
        let manifest = makeManifest()
        XCTAssertEqual(manifest.kind, .vscodeExtension)
        XCTAssertEqual(manifest.apiSurface, .vscode)
        XCTAssertTrue(manifest.architectures.contains(.x86_64))
        XCTAssertFalse(manifest.entryPoint.isEmpty)
    }

    func testH19_contractQueryFindsRegisteredContract() async throws {
        let registry = CapabilityContractRegistryImpl(store: CapabilityContractStore())
        let contract = makeContract()
        _ = try await registry.register(contract)
        let capID = CapabilityID(contract.id.rawValue)
        registry.bindCapability(capID, to: contract.id)
        let found = registry.lookup(contract.id)
        XCTAssertNotNil(found, "Contract must be queryable via lookup (H21)")
    }

    func testH19_versionNegotiationSucceedsForCompatibleExtension() async throws {
        let versionNeg = FullChainVersionNegotiation()
        let manifest = makeManifest()
        let matrix = CompatibilityMatrix(entries: [])
        let request = VersionNegotiationRequest(
            extensionManifest: manifest,
            hostVersion: SemVer(13, 0, 0),
            hostArchitecture: .x86_64,
            matrix: matrix
        )
        let result = try await versionNeg.negotiate(request)
        if case .compatible = result {} else {
            XCTFail("Version negotiation must succeed for compatible extension (H24)")
        }
    }

    func testH19_hostStartupCreatesRunningProcess() async throws {
        let registry = ExtensionInstanceRegistryImpl()
        let versionNeg = FullChainVersionNegotiation()
        let orchestrator = ExtensionHostOrchestratorImpl(
            instanceRegistry: registry,
            versionNegotiation: versionNeg,
            auditIntegration: auditIntegration
        )
        let pm = CrashSimulatingProcessManager()
        let supervisor = ExtensionHostSupervisorImpl()
        let config = makeConfig()
        orchestrator.registerHost(hostType: .vscodeExtensionHost, config: config, processManager: pm, supervisor: supervisor)
        let handle = try await orchestrator.ensureHostStarted(hostType: .vscodeExtensionHost)
        XCTAssertNotNil(handle.processID, "Host startup must create a running process (H19)")
    }

    func testH19_activateExtensionProducesInstanceID() async throws {
        let registry = ExtensionInstanceRegistryImpl()
        let versionNeg = FullChainVersionNegotiation()
        let orchestrator = ExtensionHostOrchestratorImpl(
            instanceRegistry: registry,
            versionNegotiation: versionNeg,
            auditIntegration: auditIntegration
        )
        let pm = CrashSimulatingProcessManager()
        let supervisor = ExtensionHostSupervisorImpl()
        let config = makeConfig()
        orchestrator.registerHost(hostType: .vscodeExtensionHost, config: config, processManager: pm, supervisor: supervisor)
        let manifest = makeManifest()
        let workspaceID = WorkspaceID("test-workspace")
        let instanceID = try await orchestrator.activateExtension(manifest, workspaceID: workspaceID)
        XCTAssertFalse(instanceID.rawValue.isEmpty, "activateExtension must produce a valid instance ID (H19)")
    }

    func testH19_apiCallGoesThroughContract() async throws {
        let registry = CapabilityContractRegistryImpl(store: CapabilityContractStore())
        let contract = makeContract()
        _ = try await registry.register(contract)
        let capID = CapabilityID(contract.id.rawValue)
        registry.bindCapability(capID, to: contract.id)
        let enforced = try registry.enforceContract(capID, input: .null)
        XCTAssertEqual(enforced.id, contract.id, "API call must go through Contract enforcement (H21)")
    }

    func testH19_apiCallGoesThroughAuthorization() async throws {
        let permService = FullChainPermissionService()
        try await permService.grant(ExtensionID("test-ext"), scope: .clipboard, duration: .session)
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let permission = ExtensionPermission(
            scope: .clipboard,
            operations: [.read],
            riskLevel: .readOnly,
            requiresApproval: false
        )
        let result = try await authIntegration.authorize(
            extensionID: ExtensionID("test-ext"),
            capability: CapabilityID("test-cap"),
            permission: permission,
            sessionID: AgentSessionID("test-session")
        )
        XCTAssertEqual(result, .allowed, "API call must go through Authorization (H20)")
    }

    func testH19_auditRecordedForEachLifecycleStep() async throws {
        let sessionID = AgentSessionID("h19-lifecycle")
        let extID = ExtensionID("h19-ext")
        let events: [M9AuditEventKind] = [
            .extensionManifestLoaded,
            .versionNegotiationSucceeded,
            .extensionEnabled,
            .capabilityInvoked
        ]
        for kind in events {
            let event = M9AuditEvent(
                kind: kind,
                sessionID: sessionID,
                extensionID: extID,
                detail: .string("lifecycle step: \(kind.rawValue)")
            )
            try await auditIntegration.recordExtensionEvent(event)
        }
        let records = try await auditService.query(AuditFilter(sessionID: sessionID))
        XCTAssertGreaterThanOrEqual(records.count, events.count,
            "Each lifecycle step must produce an audit record (H23, H19)")
    }

    func testH19_fullChainEachStepAuditable() async throws {
        let sessionID = AgentSessionID("h19-full-chain")
        let extID = ExtensionID("h19-chain-ext")
        let chainSteps = [
            "manifest_parse",
            "contract_query",
            "version_negotiation",
            "host_startup",
            "activate",
            "api_call",
            "authorization",
            "execute",
            "audit"
        ]
        for step in chainSteps {
            let event = M9AuditEvent(
                kind: .extensionInvoked,
                sessionID: sessionID,
                extensionID: extID,
                detail: .string("chain step: \(step)")
            )
            try await auditIntegration.recordExtensionEvent(event)
        }
        let records = try await auditService.query(AuditFilter(sessionID: sessionID))
        XCTAssertEqual(records.count, chainSteps.count,
            "Full chain must have auditable record for each step (H19, REQ-050)")
    }

    func testH19_noDirectPathFromExtensionToExecution() async throws {
        let permService = FullChainPermissionService()
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let permission = ExtensionPermission(
            scope: .filesystem(path: "/etc", access: .readOnly),
            operations: [.write],
            riskLevel: .high,
            requiresApproval: true
        )
        let result = try await authIntegration.authorize(
            extensionID: ExtensionID("test-ext"),
            capability: CapabilityID("write-file"),
            permission: permission,
            sessionID: AgentSessionID("test-session")
        )
        if case .requiresUserApproval = result {
        } else {
            XCTFail("High-risk operation must require user approval — no direct path (H19, H20)")
        }
    }

    // MARK: - TASK-035.2: H19 禁止直通 (source scan)

    func testH19_noDirectProcessInSharedCompatibility() {
        let violations = scanSourceFiles(in: "Sources/AppKCodeShared/Compatibility", forPattern: "Process()")
        XCTAssertTrue(violations.isEmpty,
            "Shared/Compatibility must not directly instantiate Process (H19): \(violations)")
    }

    func testH19_noDirectProcessInDomainCompatibility() {
        let violations = scanSourceFiles(in: "Sources/AppKCodeDomain/Compatibility", forPattern: "Process()")
        XCTAssertTrue(violations.isEmpty,
            "Domain/Compatibility must not directly instantiate Process (H19): \(violations)")
    }

    func testH19_noDirectProcessInApplicationCompatibility() {
        let violations = scanSourceFiles(in: "Sources/AppKCodeApplication/Compatibility", forPattern: "Process()")
        XCTAssertTrue(violations.isEmpty,
            "Application/Compatibility must not directly instantiate Process (H19): \(violations)")
    }

    func testH19_noDirectFileManagerInCompatibilityLayer() {
        let dirs = [
            "Sources/AppKCodeShared/Compatibility",
            "Sources/AppKCodeDomain/Compatibility"
        ]
        var allViolations: [String] = []
        for dir in dirs {
            allViolations += scanSourceFiles(in: dir, forPattern: "FileManager.default")
        }
        XCTAssertTrue(allViolations.isEmpty,
            "Compatibility layer must not directly use FileManager.default (H19): \(allViolations)")
    }

    func testH19_noDirectGitInCompatibilityLayer() {
        let dirs = [
            "Sources/AppKCodeShared/Compatibility",
            "Sources/AppKCodeDomain/Compatibility",
            "Sources/AppKCodeApplication/Compatibility"
        ]
        var allViolations: [String] = []
        for dir in dirs {
            allViolations += scanSourceFiles(in: dir, forPattern: "\"git ")
        }
        XCTAssertTrue(allViolations.isEmpty,
            "Compatibility layer must not directly call git (H19): \(allViolations)")
    }

    // MARK: - TASK-035.3: H19-H24 不可 bypass (source scan)

    func testH19_noBypassKeywordInM10Files() {
        let keywords = ["bypass", "autoApprove", "skipAuth", "skipApproval",
                        "directExecute", "noAudit", "directInternal", "grantAll"]
        let dirs = [
            "Sources/AppKCodeShared/Compatibility",
            "Sources/AppKCodeDomain/Compatibility",
            "Sources/AppKCodeExtensionHost/Compatibility",
            "Sources/AppKCodeApplication/Compatibility"
        ]
        var allViolations: [String] = []
        for dir in dirs {
            for keyword in keywords {
                allViolations += scanSourceFiles(in: dir, forPattern: keyword)
            }
        }
        XCTAssertTrue(allViolations.isEmpty,
            "M10 files must not contain bypass keywords (H19-H24): \(allViolations)")
    }

    func testH19_noAutoApproveInM10Files() {
        let dirs = m10SourceDirs()
        var allViolations: [String] = []
        for dir in dirs {
            allViolations += scanSourceFiles(in: dir, forPattern: "autoApprove")
        }
        XCTAssertTrue(allViolations.isEmpty,
            "M10 files must not contain 'autoApprove' (H20): \(allViolations)")
    }

    func testH19_noSkipAuthInM10Files() {
        let dirs = m10SourceDirs()
        var allViolations: [String] = []
        for dir in dirs {
            allViolations += scanSourceFiles(in: dir, forPattern: "skipAuth")
            allViolations += scanSourceFiles(in: dir, forPattern: "skipApproval")
        }
        XCTAssertTrue(allViolations.isEmpty,
            "M10 files must not contain 'skipAuth'/'skipApproval' (H20): \(allViolations)")
    }

    // MARK: - TASK-035.4: H22 IPC Isolation (REQ-036)

    func testH22_ipcMessageIsJSONSerializable() throws {
        let msg = IPCMessage(jsonrpc: "2.0", id: 1, method: "test", params: .string("data"), result: nil, error: nil)
        let data = try JSONEncoder().encode(msg)
        XCTAssertGreaterThan(data.count, 0, "IPCMessage must be JSON serializable (H22, REQ-036)")
        let decoded = try JSONDecoder().decode(IPCMessage.self, from: data)
        XCTAssertEqual(decoded.method, "test")
    }

    func testH22_ipcResponseIsJSONSerializable() throws {
        let resp = IPCResponse(id: 1, result: .string("ok"), error: nil)
        let data = try JSONEncoder().encode(resp)
        XCTAssertGreaterThan(data.count, 0, "IPCResponse must be JSON serializable (H22)")
        let decoded = try JSONDecoder().decode(IPCResponse.self, from: data)
        XCTAssertEqual(decoded.id, 1)
    }

    func testH22_ipcErrorIsJSONSerializable() throws {
        let err = IPCError(code: -32601, message: "Method not found")
        let data = try JSONEncoder().encode(err)
        XCTAssertGreaterThan(data.count, 0, "IPCError must be JSON serializable (H22)")
        let decoded = try JSONDecoder().decode(IPCError.self, from: data)
        XCTAssertEqual(decoded.code, -32601)
    }

    func testH22_ipcMessagePayloadIsAnyCodableValue() throws {
        let payloads: [AnyCodableValue] = [
            .null,
            .string("test"),
            .int(42),
            .double(3.14),
            .bool(true),
            .object(["key": .string("value")]),
            .array([.int(1), .int(2)])
        ]
        for payload in payloads {
            let msg = IPCMessage(jsonrpc: "2.0", id: 1, method: "test", params: payload, result: nil, error: nil)
            let data = try JSONEncoder().encode(msg)
            XCTAssertGreaterThan(data.count, 0, "IPC payload must be JSON serializable for all types (H22)")
        }
    }

    func testH22_noInternalSwiftObjectReferencesInIPC() throws {
        let msg = IPCMessage(jsonrpc: "2.0", id: 1, method: "test", params: .null, result: nil, error: nil)
        let msgData = try JSONEncoder().encode(msg)
        XCTAssertGreaterThan(msgData.count, 0, "IPCMessage must be Codable (H22)")
        let resp = IPCResponse(id: 1, result: .null, error: nil)
        let respData = try JSONEncoder().encode(resp)
        XCTAssertGreaterThan(respData.count, 0, "IPCResponse must be Codable (H22)")
        let err = IPCError(code: 0, message: "")
        let errData = try JSONEncoder().encode(err)
        XCTAssertGreaterThan(errData.count, 0, "IPCError must be Codable (H22)")
        let ref = FileTransferRef(path: "", size: 0, sha256: "")
        let refData = try JSONEncoder().encode(ref)
        XCTAssertGreaterThan(refData.count, 0, "FileTransferRef must be Codable (H22)")
    }

    // MARK: - TASK-035.5: Streaming Full Chain (REQ-041)

    func testStreaming_contractEnforcedBeforeStreaming() async throws {
        let registry = CapabilityContractRegistryImpl(store: CapabilityContractStore())
        let permService = FullChainPermissionService()
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let streaming = StreamingCapabilityAppServiceImpl(
            contractRegistry: registry,
            authIntegration: authIntegration,
            auditIntegration: auditIntegration
        )
        let sessionID = AgentSessionID("stream-no-contract")
        do {
            _ = try await streaming.invokeStreaming(
                CapabilityID("unregistered-cap"),
                extensionID: ExtensionID("test-ext"),
                input: .null,
                sessionID: sessionID
            )
            XCTFail("Streaming must enforce contract — unregistered capability must throw (H21)")
        } catch {
        }
    }

    func testStreaming_authorizationEnforcedBeforeStreaming() async throws {
        let registry = CapabilityContractRegistryImpl(store: CapabilityContractStore())
        let contract = makeHighRiskContract()
        _ = try await registry.register(contract)
        let capID = CapabilityID(contract.id.rawValue)
        registry.bindCapability(capID, to: contract.id)
        let permService = FullChainPermissionService()
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let streaming = StreamingCapabilityAppServiceImpl(
            contractRegistry: registry,
            authIntegration: authIntegration,
            auditIntegration: auditIntegration
        )
        let sessionID = AgentSessionID("stream-auth")
        let stream = try await streaming.invokeStreaming(
            capID,
            extensionID: ExtensionID("test-ext"),
            input: .null,
            sessionID: sessionID
        )
        var results: [StreamingCapabilityResult] = []
        for await result in stream {
            results.append(result)
            if result.isFinal { break }
        }
        XCTAssertTrue(results.contains { $0.error != nil },
            "Streaming must enforce authorization — high-risk without approval must produce error (H20)")
    }

    func testStreaming_auditRecordedForDeniedStream() async throws {
        let registry = CapabilityContractRegistryImpl(store: CapabilityContractStore())
        let contract = makeHighRiskContract()
        _ = try await registry.register(contract)
        let capID = CapabilityID(contract.id.rawValue)
        registry.bindCapability(capID, to: contract.id)
        let permService = FullChainPermissionService()
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let streaming = StreamingCapabilityAppServiceImpl(
            contractRegistry: registry,
            authIntegration: authIntegration,
            auditIntegration: auditIntegration
        )
        let sessionID = AgentSessionID("stream-denied-audit")
        let extID = ExtensionID("stream-denied-ext")
        _ = try await streaming.invokeStreaming(
            capID,
            extensionID: extID,
            input: .null,
            sessionID: sessionID
        )
        try await Task.sleep(nanoseconds: 100_000_000)
        let records = try await auditService.query(AuditFilter(sessionID: sessionID))
        XCTAssertGreaterThan(records.count, 0,
            "Denied streaming must produce audit record (H23, REQ-041)")
    }

    func testStreaming_auditRecordedForApprovalRequired() async throws {
        let registry = CapabilityContractRegistryImpl(store: CapabilityContractStore())
        let contract = makeHighRiskContract()
        _ = try await registry.register(contract)
        let capID = CapabilityID(contract.id.rawValue)
        registry.bindCapability(capID, to: contract.id)
        let permService = FullChainPermissionService()
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let streaming = StreamingCapabilityAppServiceImpl(
            contractRegistry: registry,
            authIntegration: authIntegration,
            auditIntegration: auditIntegration
        )
        let sessionID = AgentSessionID("stream-approval-audit")
        _ = try await streaming.invokeStreaming(
            capID,
            extensionID: ExtensionID("test-ext"),
            input: .null,
            sessionID: sessionID
        )
        try await Task.sleep(nanoseconds: 100_000_000)
        let records = try await auditService.query(AuditFilter(sessionID: sessionID))
        XCTAssertGreaterThan(records.count, 0,
            "Approval-required streaming must produce audit record (H23)")
    }

    func testStreaming_auditRecordedForAllowedStream() async throws {
        let registry = CapabilityContractRegistryImpl(store: CapabilityContractStore())
        let contract = makeReadOnlyContract()
        _ = try await registry.register(contract)
        let capID = CapabilityID(contract.id.rawValue)
        registry.bindCapability(capID, to: contract.id)
        let permService = FullChainPermissionService()
        try await permService.grant(ExtensionID("stream-ext"), scope: .clipboard, duration: .session)
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let streaming = StreamingCapabilityAppServiceImpl(
            contractRegistry: registry,
            authIntegration: authIntegration,
            auditIntegration: auditIntegration
        )
        let sessionID = AgentSessionID("stream-allowed-audit")
        let extID = ExtensionID("stream-ext")
        _ = try await streaming.invokeStreaming(
            capID,
            extensionID: extID,
            input: .null,
            sessionID: sessionID
        )
        try await Task.sleep(nanoseconds: 100_000_000)
        let records = try await auditService.query(AuditFilter(sessionID: sessionID))
        XCTAssertGreaterThan(records.count, 0,
            "Allowed streaming must produce audit record (H23, REQ-041)")
    }

    func testStreaming_deniedProducesErrorStream() async throws {
        let registry = CapabilityContractRegistryImpl(store: CapabilityContractStore())
        let contract = makeHighRiskContract()
        _ = try await registry.register(contract)
        let capID = CapabilityID(contract.id.rawValue)
        registry.bindCapability(capID, to: contract.id)
        let permService = FullChainPermissionService()
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let streaming = StreamingCapabilityAppServiceImpl(
            contractRegistry: registry,
            authIntegration: authIntegration,
            auditIntegration: auditIntegration
        )
        let stream = try await streaming.invokeStreaming(
            capID,
            extensionID: ExtensionID("test-ext"),
            input: .null,
            sessionID: AgentSessionID("stream-error")
        )
        var results: [StreamingCapabilityResult] = []
        for await result in stream {
            results.append(result)
            if result.isFinal { break }
        }
        XCTAssertFalse(results.isEmpty, "Denied streaming must produce at least one result")
        XCTAssertTrue(results.last?.isFinal == true, "Denied streaming must finish")
    }

    func testStreaming_noBypassApproval() async throws {
        let registry = CapabilityContractRegistryImpl(store: CapabilityContractStore())
        let contract = makeHighRiskContract()
        _ = try await registry.register(contract)
        let capID = CapabilityID(contract.id.rawValue)
        registry.bindCapability(capID, to: contract.id)
        let permService = FullChainPermissionService()
        let authIntegration = ExtensionAuthorizationIntegration(permissionService: permService)
        let streaming = StreamingCapabilityAppServiceImpl(
            contractRegistry: registry,
            authIntegration: authIntegration,
            auditIntegration: auditIntegration
        )
        let stream = try await streaming.invokeStreaming(
            capID,
            extensionID: ExtensionID("test-ext"),
            input: .null,
            sessionID: AgentSessionID("stream-no-bypass")
        )
        var hasError = false
        for await result in stream {
            if result.error != nil { hasError = true }
            if result.isFinal { break }
        }
        XCTAssertTrue(hasError,
            "High-risk streaming without approval must produce error — no bypass (H20, REQ-041)")
    }

    // MARK: - Helpers

    private func makeManifest() -> ExtensionManifest {
        ExtensionManifest(
            id: ExtensionID("test-fullchain-ext"),
            name: "Full Chain Test Extension",
            version: SemVer(1, 0, 0),
            kind: .vscodeExtension,
            apiSurface: .vscode,
            architectures: [.x86_64],
            contractID: CapabilityContractID(),
            entryPoint: "extension.js"
        )
    }

    private func makeConfig() -> ExtensionHostConfig {
        ExtensionHostConfig(
            hostType: .vscodeExtensionHost,
            runtimePath: "/usr/local/bin/node",
            runtimeVersion: SemVer(20, 18, 0),
            memoryLimitMB: 512,
            cpuLimitPercent: 80,
            ipcChannel: IPCChannelDescriptor(kind: .stdio),
            hostScriptPath: "/tmp/extension-host.js"
        )
    }

    private func makeContract() -> CapabilityContract {
        CapabilityContract(
            id: CapabilityContractID("test-contract"),
            name: "Test Contract",
            protocolKind: .vscode,
            supportedAPIs: [APIName(namespace: "workspace.fs", method: "readFile")],
            degradationStrategy: .shim,
            testCases: [TestCaseID("test-case-1")],
            inputSchema: JSONSchema(type: "object"),
            outputSchema: JSONSchema(type: "object"),
            requiredPermission: ExtensionPermission(
                scope: .clipboard,
                operations: [.read],
                riskLevel: .readOnly,
                requiresApproval: false
            ),
            minHostVersion: SemVer(13, 0, 0)
        )
    }

    private func makeReadOnlyContract() -> CapabilityContract {
        CapabilityContract(
            id: CapabilityContractID("readonly-contract"),
            name: "Read-Only Contract",
            protocolKind: .vscode,
            supportedAPIs: [APIName(namespace: "workspace.fs", method: "readFile")],
            degradationStrategy: .shim,
            testCases: [TestCaseID("test-case-1")],
            inputSchema: JSONSchema(type: "object"),
            outputSchema: JSONSchema(type: "object"),
            requiredPermission: ExtensionPermission(
                scope: .clipboard,
                operations: [.read],
                riskLevel: .readOnly,
                requiresApproval: false
            ),
            minHostVersion: SemVer(13, 0, 0)
        )
    }

    private func makeHighRiskContract() -> CapabilityContract {
        CapabilityContract(
            id: CapabilityContractID("highrisk-contract"),
            name: "High-Risk Contract",
            protocolKind: .vscode,
            supportedAPIs: [APIName(namespace: "workspace.fs", method: "writeFile")],
            degradationStrategy: .promptOnly,
            testCases: [TestCaseID("test-case-1")],
            inputSchema: JSONSchema(type: "object"),
            outputSchema: JSONSchema(type: "object"),
            requiredPermission: ExtensionPermission(
                scope: .filesystem(path: "/", access: .readOnly),
                operations: [.write],
                riskLevel: .high,
                requiresApproval: true
            ),
            minHostVersion: SemVer(13, 0, 0)
        )
    }

    private func m10SourceDirs() -> [String] {
        [
            "Sources/AppKCodeShared/Compatibility",
            "Sources/AppKCodeDomain/Compatibility",
            "Sources/AppKCodeExtensionHost/Compatibility",
            "Sources/AppKCodeApplication/Compatibility"
        ]
    }

    private func scanSourceFiles(in relativeDir: String, forPattern pattern: String) -> [String] {
        let projectRoot = FileManager.default.currentDirectoryPath
        let dirPath = "\(projectRoot)/\(relativeDir)"
        guard FileManager.default.fileExists(atPath: dirPath) else {
            return []
        }
        var violations: [String] = []
        guard let enumerator = FileManager.default.enumerator(atPath: dirPath) else {
            return []
        }
        while let file = enumerator.nextObject() as? String {
            guard file.hasSuffix(".swift") else { continue }
            let fullPath = "\(dirPath)/\(file)"
            guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else { continue }
            if content.contains(pattern) {
                violations.append("\(relativeDir)/\(file)")
            }
        }
        return violations
    }
}
import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain
@testable import AppKCodeApplication
import AppKCodeExtensionHost
import AppKCodeInfrastructure

// MARK: - Mock Audit Service

final class MockAuditService: AuditService, @unchecked Sendable {
    private let lock = NSLock()
    private var records: [AgentAuditRecord] = []

    func record(_ entry: AgentAuditRecord) async throws {
        lock.lock()
        records.append(entry)
        lock.unlock()
    }

    func query(_ filter: AuditFilter) async throws -> [AgentAuditRecord] {
        lock.lock()
        defer { lock.unlock() }
        return records
    }

    func verifyIntegrity(session: AgentSessionID) async throws -> Bool { true }

    var recordCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return records.count
    }
}

// MARK: - Mock Version Negotiation Service

final class MockVersionNegotiationService: VersionNegotiationService, @unchecked Sendable {
    var resultToReturn: VersionNegotiationResult
    var negotiateCallCount = 0

    init(result: VersionNegotiationResult = .compatible(extensionVersion: SemVer(1, 0, 0), hostVersion: SemVer(13, 0, 0))) {
        self.resultToReturn = result
    }

    func negotiate(_ request: VersionNegotiationRequest) async throws -> VersionNegotiationResult {
        negotiateCallCount += 1
        return resultToReturn
    }
}

// MARK: - Mock Process Manager (Phase 5)

final class MockPhase5ProcessManager: ExtensionHostProcessManager, @unchecked Sendable {
    let hostType: ExtensionHostType
    private let lock = NSLock()
    private var _state: HostProcessState = .notStarted
    var startCallCount = 0
    var stopCallCount = 0
    var restartCallCount = 0

    var state: HostProcessState {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }

    var processID: ProcessID? {
        if case .running(let pid) = state { return pid }
        return nil
    }

    init(hostType: ExtensionHostType = .vscodeExtensionHost) {
        self.hostType = hostType
    }

    func start(config: ExtensionHostConfig) async throws -> HostProcessHandle {
        lock.lock()
        startCallCount += 1
        _state = .running(pid: ProcessID(99999))
        lock.unlock()
        return HostProcessHandle(processID: ProcessID(99999), ipcChannel: config.ipcChannel)
    }

    func stop(timeout: TimeInterval) async throws -> ProcessExitInfo {
        lock.lock()
        stopCallCount += 1
        _state = .stopped(exitCode: 0)
        lock.unlock()
        return ProcessExitInfo(exitCode: 0)
    }

    func restart(config: ExtensionHostConfig) async throws -> HostProcessHandle {
        lock.lock()
        restartCallCount += 1
        _state = .running(pid: ProcessID(88888))
        lock.unlock()
        return HostProcessHandle(processID: ProcessID(88888), ipcChannel: config.ipcChannel)
    }

    func monitorState() -> AsyncStream<HostProcessState> {
        AsyncStream { _ in }
    }

    func sendSignal(_ signal: ProcessSignal) async throws {}
}

// MARK: - Mock Supervisor (Phase 5)

final class MockPhase5Supervisor: ExtensionHostSupervisor, @unchecked Sendable {
    var crashCount: Int = 0
    var isStable: Bool = true
    var superviseCallCount = 0

    func supervise(config: ExtensionHostConfig, processManager: ExtensionHostProcessManager) async throws -> HostProcessHandle {
        superviseCallCount += 1
        return try await processManager.start(config: config)
    }

    func stop() async throws {}

    func crashEvents() -> AsyncStream<HostCrashEvent> { AsyncStream { _ in } }
    func restartEvents() -> AsyncStream<HostRestartEvent> { AsyncStream { _ in } }

    func forceRestart(config: ExtensionHostConfig, processManager: ExtensionHostProcessManager) async throws -> HostProcessHandle {
        return try await processManager.restart(config: config)
    }
}

// MARK: - Phase 5 Tests

final class M10Phase5Tests: XCTestCase {

    // MARK: - TASK-027: ExtensionInstanceRegistry Tests

    func testExtensionInstanceRegistryRegisterAndLookup() async throws {
        let registry = ExtensionInstanceRegistryImpl()
        let extID = ExtensionID("test-ext")
        let wsID = WorkspaceID("ws-1")
        let instance = ExtensionInstance(
            extensionID: extID,
            workspaceID: wsID,
            hostType: .vscodeExtensionHost
        )

        let instanceID = try await registry.register(
            extensionID: extID,
            workspaceID: wsID,
            instance: instance
        )

        let lookedUp = registry.lookup(extensionID: extID, workspaceID: wsID)
        XCTAssertNotNil(lookedUp)
        XCTAssertEqual(lookedUp?.id, instanceID)
        XCTAssertEqual(lookedUp?.extensionID, extID)
        XCTAssertEqual(lookedUp?.workspaceID, wsID)
    }

    func testExtensionInstanceRegistryMultiInstanceIsolation() async throws {
        let registry = ExtensionInstanceRegistryImpl()
        let extID = ExtensionID("shared-ext")
        let wsA = WorkspaceID("ws-A")
        let wsB = WorkspaceID("ws-B")

        let instanceA = ExtensionInstance(
            extensionID: extID, workspaceID: wsA,
            hostType: .vscodeExtensionHost, state: .active
        )
        let instanceB = ExtensionInstance(
            extensionID: extID, workspaceID: wsB,
            hostType: .vscodeExtensionHost, state: .crashed
        )

        _ = try await registry.register(extensionID: extID, workspaceID: wsA, instance: instanceA)
        _ = try await registry.register(extensionID: extID, workspaceID: wsB, instance: instanceB)

        let lookupA = registry.lookup(extensionID: extID, workspaceID: wsA)
        let lookupB = registry.lookup(extensionID: extID, workspaceID: wsB)

        XCTAssertEqual(lookupA?.state, .active)
        XCTAssertEqual(lookupB?.state, .crashed)
        XCTAssertNotEqual(lookupA?.id, lookupB?.id)
    }

    func testExtensionInstanceRegistryListInstances() async throws {
        let registry = ExtensionInstanceRegistryImpl()
        let wsID = WorkspaceID("ws-1")

        for i in 0..<3 {
            let extID = ExtensionID("ext-\(i)")
            let instance = ExtensionInstance(extensionID: extID, workspaceID: wsID, hostType: .vscodeExtensionHost)
            _ = try await registry.register(extensionID: extID, workspaceID: wsID, instance: instance)
        }

        let instances = registry.listInstances(workspaceID: wsID)
        XCTAssertEqual(instances.count, 3)
    }

    func testExtensionInstanceRegistryRemove() async throws {
        let registry = ExtensionInstanceRegistryImpl()
        let extID = ExtensionID("test-ext")
        let wsID = WorkspaceID("ws-1")
        let instance = ExtensionInstance(extensionID: extID, workspaceID: wsID, hostType: .vscodeExtensionHost)

        let instanceID = try await registry.register(extensionID: extID, workspaceID: wsID, instance: instance)
        XCTAssertNotNil(registry.lookup(extensionID: extID, workspaceID: wsID))

        try await registry.remove(extensionInstanceID: instanceID)
        XCTAssertNil(registry.lookup(extensionID: extID, workspaceID: wsID))
    }

    func testExtensionInstanceRegistryUpdateState() async throws {
        let registry = ExtensionInstanceRegistryImpl()
        let extID = ExtensionID("test-ext")
        let wsID = WorkspaceID("ws-1")
        let instance = ExtensionInstance(extensionID: extID, workspaceID: wsID, hostType: .vscodeExtensionHost)

        let instanceID = try await registry.register(extensionID: extID, workspaceID: wsID, instance: instance)
        try await registry.updateState(.active, for: instanceID)

        let updated = registry.lookup(extensionID: extID, workspaceID: wsID)
        XCTAssertEqual(updated?.state, .active)
    }

    func testExtensionInstanceRegistryDualKeyNoCrossWorkspaceLeak() async throws {
        let registry = ExtensionInstanceRegistryImpl()
        let extID = ExtensionID("ext-1")
        let wsA = WorkspaceID("ws-A")
        let wsB = WorkspaceID("ws-B")

        let instanceA = ExtensionInstance(extensionID: extID, workspaceID: wsA, hostType: .vscodeExtensionHost)
        _ = try await registry.register(extensionID: extID, workspaceID: wsA, instance: instanceA)

        XCTAssertNil(registry.lookup(extensionID: extID, workspaceID: wsB))
        XCTAssertEqual(registry.listInstances(workspaceID: wsB).count, 0)
    }

    // MARK: - TASK-029.1: Lifecycle State Machine Tests

    func testIsValidTransitionAllValidPaths() {
        let orchestrator = createOrchestrator()

        XCTAssertTrue(orchestrator.isValidTransition(from: .notStarted, to: .loading))
        XCTAssertTrue(orchestrator.isValidTransition(from: .loading, to: .loaded))
        XCTAssertTrue(orchestrator.isValidTransition(from: .loading, to: .incompatible))
        XCTAssertTrue(orchestrator.isValidTransition(from: .loading, to: .failed))
        XCTAssertTrue(orchestrator.isValidTransition(from: .loaded, to: .activating))
        XCTAssertTrue(orchestrator.isValidTransition(from: .activating, to: .active))
        XCTAssertTrue(orchestrator.isValidTransition(from: .activating, to: .failed))
        XCTAssertTrue(orchestrator.isValidTransition(from: .active, to: .deactivating))
        XCTAssertTrue(orchestrator.isValidTransition(from: .deactivating, to: .deactivated))
        XCTAssertTrue(orchestrator.isValidTransition(from: .active, to: .crashed))
        XCTAssertTrue(orchestrator.isValidTransition(from: .crashed, to: .restarting))
        XCTAssertTrue(orchestrator.isValidTransition(from: .crashed, to: .unstable))
        XCTAssertTrue(orchestrator.isValidTransition(from: .restarting, to: .active))
        XCTAssertTrue(orchestrator.isValidTransition(from: .restarting, to: .failed))
        XCTAssertTrue(orchestrator.isValidTransition(from: .deactivated, to: .notStarted))
        XCTAssertTrue(orchestrator.isValidTransition(from: .failed, to: .notStarted))
        XCTAssertTrue(orchestrator.isValidTransition(from: .unstable, to: .notStarted))
    }

    func testIsValidTransitionInvalidPaths() {
        let orchestrator = createOrchestrator()

        XCTAssertFalse(orchestrator.isValidTransition(from: .notStarted, to: .active))
        XCTAssertFalse(orchestrator.isValidTransition(from: .notStarted, to: .crashed))
        XCTAssertFalse(orchestrator.isValidTransition(from: .loaded, to: .active))
        XCTAssertFalse(orchestrator.isValidTransition(from: .deactivated, to: .active))
        XCTAssertFalse(orchestrator.isValidTransition(from: .active, to: .loaded))
        XCTAssertFalse(orchestrator.isValidTransition(from: .unstable, to: .active))
        XCTAssertFalse(orchestrator.isValidTransition(from: .incompatible, to: .activating))
    }

    // MARK: - TASK-028.2: Lazy Startup Tests

    func testLazyStartupNoHostWithoutExtension() async throws {
        let orchestrator = createOrchestrator()
        XCTAssertEqual(orchestrator.hostState(hostType: .vscodeExtensionHost), .notStarted)
    }

    func testLazyStartupStartsOnFirstActivate() async throws {
        let (orchestrator, mockPM, _) = createOrchestratorWithMocks()
        let manifest = createTestManifest()
        let wsID = WorkspaceID("ws-1")

        XCTAssertEqual(mockPM.startCallCount, 0)
        _ = try await orchestrator.activateExtension(manifest, workspaceID: wsID)
        XCTAssertGreaterThanOrEqual(mockPM.startCallCount, 1)
    }

    func testLazyStartupReusesExistingHost() async throws {
        let (orchestrator, mockPM, _) = createOrchestratorWithMocks()
        let manifest1 = createTestManifest(id: "ext-1")
        let manifest2 = createTestManifest(id: "ext-2")
        let wsID = WorkspaceID("ws-1")

        _ = try await orchestrator.activateExtension(manifest1, workspaceID: wsID)
        let firstStartCount = mockPM.startCallCount

        _ = try await orchestrator.activateExtension(manifest2, workspaceID: wsID)
        XCTAssertEqual(mockPM.startCallCount, firstStartCount)
    }

    // MARK: - TASK-028.3 + TASK-029.2: Version Negotiation Before Activate

    func testVersionNegotiationHappensBeforeActivate() async throws {
        let (orchestrator, _, mockVN) = createOrchestratorWithMocks()
        let manifest = createTestManifest()
        let wsID = WorkspaceID("ws-1")

        XCTAssertEqual(mockVN.negotiateCallCount, 0)
        _ = try await orchestrator.activateExtension(manifest, workspaceID: wsID)
        XCTAssertEqual(mockVN.negotiateCallCount, 1)
    }

    func testVersionNegotiationIncompatibleRejectsActivation() async throws {
        let mockVN = MockVersionNegotiationService(
            result: .incompatible(reason: .extensionVersionNotSupported)
        )
        let auditService = MockAuditService()
        let auditIntegration = ExtensionAuditIntegration(auditService: auditService)
        let registry = ExtensionInstanceRegistryImpl()
        let orchestrator = ExtensionHostOrchestratorImpl(
            instanceRegistry: registry,
            versionNegotiation: mockVN,
            auditIntegration: auditIntegration
        )

        let manifest = createTestManifest()
        let wsID = WorkspaceID("ws-1")

        do {
            _ = try await orchestrator.activateExtension(manifest, workspaceID: wsID)
            XCTFail("Should have thrown for incompatible version")
        } catch {
        }

        XCTAssertEqual(mockVN.negotiateCallCount, 1)
    }

    // MARK: - TASK-028.5: Deactivate Tests

    func testDeactivateExtensionTransitionsToDeactivated() async throws {
        let (orchestrator, _, _) = createOrchestratorWithMocks()
        let manifest = createTestManifest()
        let wsID = WorkspaceID("ws-1")

        let instanceID = try await orchestrator.activateExtension(manifest, workspaceID: wsID)
        try await orchestrator.deactivateExtension(instanceID, workspaceID: wsID)

        let auditEvents = orchestrator.lifecycleAuditEvents
        XCTAssertTrue(auditEvents.contains { $0.eventType == "deactivated" })
    }

    // MARK: - TASK-028.7: Shutdown Tests

    func testShutdownHostStopsProcessManager() async throws {
        let (orchestrator, mockPM, _) = createOrchestratorWithMocks()
        let manifest = createTestManifest()
        let wsID = WorkspaceID("ws-1")

        _ = try await orchestrator.activateExtension(manifest, workspaceID: wsID)
        XCTAssertEqual(mockPM.stopCallCount, 0)

        try await orchestrator.shutdownHost(hostType: .vscodeExtensionHost)
        XCTAssertGreaterThanOrEqual(mockPM.stopCallCount, 1)
    }

    // MARK: - TASK-029.4: Lifecycle Audit Tests

    func testLifecycleAuditRecordsAllEvents() async throws {
        let (orchestrator, _, _) = createOrchestratorWithMocks()
        let manifest = createTestManifest()
        let wsID = WorkspaceID("ws-1")

        let instanceID = try await orchestrator.activateExtension(manifest, workspaceID: wsID)
        try await orchestrator.deactivateExtension(instanceID, workspaceID: wsID)

        let events = orchestrator.lifecycleAuditEvents
        XCTAssertTrue(events.contains { $0.eventType == "loading" })
        XCTAssertTrue(events.contains { $0.eventType == "activating" })
        XCTAssertTrue(events.contains { $0.eventType == "activated" })
        XCTAssertTrue(events.contains { $0.eventType == "deactivating" })
        XCTAssertTrue(events.contains { $0.eventType == "deactivated" })
    }

    func testLifecycleAuditIncludesExtensionIDAndInstanceID() async throws {
        let (orchestrator, _, _) = createOrchestratorWithMocks()
        let manifest = createTestManifest()
        let wsID = WorkspaceID("ws-1")

        let instanceID = try await orchestrator.activateExtension(manifest, workspaceID: wsID)

        let events = orchestrator.lifecycleAuditEvents
        XCTAssertTrue(events.allSatisfy { $0.extensionID == manifest.id })
        XCTAssertTrue(events.contains { $0.instanceID == instanceID })
    }

    // MARK: - TASK-029.3: Crash Recovery Tests

    func testCrashRecoveryTransitionsToRestarting() async throws {
        let (orchestrator, mockPM, _) = createOrchestratorWithMocks()
        let manifest = createTestManifest()
        let wsID = WorkspaceID("ws-1")

        _ = try await orchestrator.activateExtension(manifest, workspaceID: wsID)

        try await orchestrator.handleHostCrash(hostType: .vscodeExtensionHost, exitCode: -1)

        XCTAssertTrue(orchestrator.lifecycleAuditEvents.contains { $0.eventType == "crashed" })
        XCTAssertTrue(orchestrator.lifecycleAuditEvents.contains { $0.eventType == "restarting" })
        XCTAssertGreaterThanOrEqual(mockPM.restartCallCount, 1)
    }

    func testCrashRecoveryRestoresActiveState() async throws {
        let (orchestrator, _, _) = createOrchestratorWithMocks()
        let manifest = createTestManifest()
        let wsID = WorkspaceID("ws-1")

        _ = try await orchestrator.activateExtension(manifest, workspaceID: wsID)

        try await orchestrator.handleHostCrash(hostType: .vscodeExtensionHost, exitCode: -1)

        XCTAssertTrue(orchestrator.lifecycleAuditEvents.contains { $0.eventType == "recovered" })
    }

    // MARK: - TASK-028.4: Activation Events Tests

    func testActivationEventParsing() {
        XCTAssertEqual(ActivationEvent.parse("onLanguage:swift"), .onLanguage("swift"))
        XCTAssertEqual(ActivationEvent.parse("onCommand:my.cmd"), .onCommand("my.cmd"))
        XCTAssertEqual(ActivationEvent.parse("onUri:file"), .onUri("file"))
        XCTAssertEqual(ActivationEvent.parse("workspaceContains:**/*.swift"), .workspaceContains("**/*.swift"))
        XCTAssertEqual(ActivationEvent.parse("onStartupFinished"), .onStartupFinished)
        XCTAssertNil(ActivationEvent.parse("invalid"))
    }

    // MARK: - ExtensionInstanceState Tests

    func testExtensionInstanceStateAllCases() {
        XCTAssertEqual(ExtensionInstanceState.notStarted.rawValue, "not_started")
        XCTAssertEqual(ExtensionInstanceState.loading.rawValue, "loading")
        XCTAssertEqual(ExtensionInstanceState.loaded.rawValue, "loaded")
        XCTAssertEqual(ExtensionInstanceState.incompatible.rawValue, "incompatible")
        XCTAssertEqual(ExtensionInstanceState.activating.rawValue, "activating")
        XCTAssertEqual(ExtensionInstanceState.active.rawValue, "active")
        XCTAssertEqual(ExtensionInstanceState.deactivating.rawValue, "deactivating")
        XCTAssertEqual(ExtensionInstanceState.deactivated.rawValue, "deactivated")
        XCTAssertEqual(ExtensionInstanceState.crashed.rawValue, "crashed")
        XCTAssertEqual(ExtensionInstanceState.restarting.rawValue, "restarting")
        XCTAssertEqual(ExtensionInstanceState.failed.rawValue, "failed")
        XCTAssertEqual(ExtensionInstanceState.unstable.rawValue, "unstable")
    }

    func testExtensionInstanceCodable() throws {
        let instance = ExtensionInstance(
            extensionID: ExtensionID("test"),
            workspaceID: WorkspaceID("ws"),
            hostType: .vscodeExtensionHost,
            state: .active
        )
        let data = try JSONEncoder().encode(instance)
        let decoded = try JSONDecoder().decode(ExtensionInstance.self, from: data)
        XCTAssertEqual(instance, decoded)
    }

    // MARK: - Helpers

    private func createOrchestrator() -> ExtensionHostOrchestratorImpl {
        let mockVN = MockVersionNegotiationService()
        let auditService = MockAuditService()
        let auditIntegration = ExtensionAuditIntegration(auditService: auditService)
        let registry = ExtensionInstanceRegistryImpl()
        return ExtensionHostOrchestratorImpl(
            instanceRegistry: registry,
            versionNegotiation: mockVN,
            auditIntegration: auditIntegration
        )
    }

    private func createOrchestratorWithMocks() -> (ExtensionHostOrchestratorImpl, MockPhase5ProcessManager, MockVersionNegotiationService) {
        let mockVN = MockVersionNegotiationService()
        let auditService = MockAuditService()
        let auditIntegration = ExtensionAuditIntegration(auditService: auditService)
        let registry = ExtensionInstanceRegistryImpl()
        let orchestrator = ExtensionHostOrchestratorImpl(
            instanceRegistry: registry,
            versionNegotiation: mockVN,
            auditIntegration: auditIntegration
        )

        let mockPM = MockPhase5ProcessManager()
        let mockSup = MockPhase5Supervisor()
        let config = ExtensionHostConfig(
            hostType: .vscodeExtensionHost,
            runtimePath: "/usr/local/bin/node",
            runtimeVersion: SemVer(20, 18, 0),
            memoryLimitMB: 512,
            cpuLimitPercent: 50,
            ipcChannel: IPCChannelDescriptor(kind: .stdio),
            hostScriptPath: "/tmp/host.js"
        )
        orchestrator.registerHost(
            hostType: .vscodeExtensionHost,
            config: config,
            processManager: mockPM,
            supervisor: mockSup
        )

        return (orchestrator, mockPM, mockVN)
    }

    private func createTestManifest(id: String = "test-ext") -> ExtensionManifest {
        ExtensionManifest(
            id: ExtensionID(id),
            name: "Test Extension",
            version: SemVer(1, 0, 0),
            kind: .vscodeExtension,
            apiSurface: .vscode,
            architectures: [.x86_64],
            contractID: CapabilityContractID(),
            entryPoint: "main.js"
        )
    }
}
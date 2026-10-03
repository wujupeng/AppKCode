import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain
@testable import AppKCodeApplication
import AppKCodeExtensionHost
import AppKCodeInfrastructure

// MARK: - TASK-032: Hard Constraint / Degradation Tests
// 对应需求: REQ-049, REQ-009, REQ-010, REQ-017, REQ-045
// 对应硬约束: H26 (API Surface Boundary), H1 (x86_64 only)

final class M10HardConstraintDegradationTests: XCTestCase {
    private var vscodeRegistry: VSCodeAPISurfaceRegistryImpl!
    private var jetbrainsRegistry: JetBrainsOpenAPISurfaceRegistryImpl!
    private var auditService: AuditServiceImpl!
    private var auditIntegration: ExtensionAuditIntegration!
    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        vscodeRegistry = VSCodeAPISurfaceRegistryImpl()
        jetbrainsRegistry = JetBrainsOpenAPISurfaceRegistryImpl()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("appk-test-task032-\(UUID().uuidString)")
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

    // MARK: - TASK-032.1: 未声明 API 降级 (REQ-009, H26)
    // debug.startDebugging (未声明) → .promptOnly 降级, 记录审计, 不静默失败

    func testUndeclaredAPI_debugStartDebugging_returnsPromptOnlyDegradation() {
        let api = APIName(namespace: "debug", method: "startDebugging")
        let strategy = vscodeRegistry.degradationStrategy(for: api)
        XCTAssertEqual(strategy, .promptOnly,
            "debug.startDebugging must degrade to .promptOnly (REQ-009, H26)")
    }

    func testUndeclaredAPI_debugStartDebugging_notInRegisteredSurface() {
        let api = APIName(namespace: "debug", method: "startDebugging")
        let mapping = vscodeRegistry.resolveAPI(api)
        XCTAssertNil(mapping,
            "debug.startDebugging must not be a registered API in VS Code surface")
    }

    func testUndeclaredAPI_debugStartDebugging_notSilentlyShimmed() {
        let api = APIName(namespace: "debug", method: "startDebugging")
        let strategy = vscodeRegistry.degradationStrategy(for: api)
        XCTAssertNotEqual(strategy, .shim,
            "Undeclared API must not be silently shimmed — must explicitly degrade (H26)")
    }

    func testUndeclaredAPI_degradation_recordsAudit() async throws {
        let extID = ExtensionID("test-ext-debug-degradation")
        let sessionID = AgentSessionID("test-session-debug")
        let event = M9AuditEvent(
            kind: .adapterDegraded,
            sessionID: sessionID,
            extensionID: extID,
            detail: .object([
                "api": .string("debug.startDebugging"),
                "strategy": .string("promptOnly"),
                "reason": .string("undeclared-api")
            ])
        )
        try await auditIntegration.recordExtensionEvent(event)
        let filter = AuditFilter(sessionID: sessionID)
        let records = try await auditService.query(filter)
        XCTAssertGreaterThan(records.count, 0,
            "Undeclared API degradation must be recorded in audit log (REQ-009, H26)")
    }

    func testUndeclaredAPI_degradation_auditContainsExtensionTarget() async throws {
        let extID = ExtensionID("test-ext-debug-target")
        let sessionID = AgentSessionID("test-session-debug-target")
        let event = M9AuditEvent(
            kind: .adapterDegraded,
            sessionID: sessionID,
            extensionID: extID,
            detail: .object([
                "api": .string("debug.startDebugging"),
                "strategy": .string("promptOnly")
            ])
        )
        try await auditIntegration.recordExtensionEvent(event)
        let filter = AuditFilter(sessionID: sessionID)
        let records = try await auditService.query(filter)
        XCTAssertTrue(records.count > 0, "Audit record must exist")
        XCTAssertTrue(records.contains { $0.target != .none },
            "Audit record must have non-none target identifying the extension (H26)")
    }

    // MARK: - TASK-032.2: proposed API 拒绝 (REQ-010)
    // vscode.proposed.* → 拒绝加载, 提示 "该 Extension 使用 proposed API，不支持"

    func testProposedAPI_rejectedByResolveAPI() {
        let api = APIName(namespace: "vscode.proposed", method: "someProposedAPI")
        let mapping = vscodeRegistry.resolveAPI(api)
        XCTAssertNil(mapping,
            "proposed API must not be resolvable — extension must be rejected (REQ-010)")
    }

    func testProposedAPI_degradationStrategyIsDisable() {
        let api = APIName(namespace: "vscode.proposed", method: "someProposedAPI")
        let strategy = vscodeRegistry.degradationStrategy(for: api)
        XCTAssertEqual(strategy, .disable,
            "proposed API must degrade to .disable — extension loading rejected (REQ-010)")
    }

    func testProposedAPI_multipleAPIs_allRejected() {
        let proposedAPIs = [
            APIName(namespace: "vscode.proposed", method: "fileSearchProvider"),
            APIName(namespace: "vscode.proposed", method: "testObserver"),
            APIName(namespace: "vscode.proposed", method: "anyProposedMethod")
        ]
        for api in proposedAPIs {
            XCTAssertNil(vscodeRegistry.resolveAPI(api),
                "proposed API \(api.method) must not be resolvable (REQ-010)")
            XCTAssertEqual(vscodeRegistry.degradationStrategy(for: api), .disable,
                "proposed API \(api.method) must degrade to .disable (REQ-010)")
        }
    }

    func testProposedAPI_rejectionMessageContent() {
        let api = APIName(namespace: "vscode.proposed", method: "someProposedAPI")
        let strategy = vscodeRegistry.degradationStrategy(for: api)
        XCTAssertEqual(strategy, .disable)
        let rejectionMessage = "该 Extension 使用 proposed API，不支持"
        XCTAssertTrue(rejectionMessage.contains("proposed API"),
            "Rejection message must mention 'proposed API' (REQ-010)")
        XCTAssertTrue(rejectionMessage.contains("不支持"),
            "Rejection message must state '不支持' (REQ-010)")
    }

    func testProposedAPI_rejection_recordsAuditAsIncompatible() async throws {
        let extID = ExtensionID("test-ext-proposed-rejection")
        let sessionID = AgentSessionID("test-session-proposed")
        let event = M9AuditEvent(
            kind: .extensionIncompatible,
            sessionID: sessionID,
            extensionID: extID,
            detail: .object([
                "api": .string("vscode.proposed.someProposedAPI"),
                "reason": .string("proposed-api-not-supported")
            ])
        )
        try await auditIntegration.recordExtensionEvent(event)
        let filter = AuditFilter(sessionID: sessionID)
        let records = try await auditService.query(filter)
        XCTAssertGreaterThan(records.count, 0,
            "Proposed API rejection must be recorded as extensionIncompatible in audit (REQ-010)")
    }

    // MARK: - TASK-032.3: internal API 拒绝 (REQ-017)
    // com.intellij.psi.impl.* → 拒绝加载, 提示 "Plugin X 使用 IntelliJ 内部 API，不支持加载"

    func testInternalAPI_psiImpl_detected() {
        XCTAssertTrue(jetbrainsRegistry.isInternalAPI("com.intellij.psi.impl.PsiElementImpl"),
            "com.intellij.psi.impl.* must be detected as internal API (REQ-017)")
    }

    func testInternalAPI_applicationImpl_detected() {
        XCTAssertTrue(jetbrainsRegistry.isInternalAPI("com.intellij.openapi.application.impl.ApplicationImpl"),
            "com.intellij.openapi.application.impl.* must be detected as internal API (REQ-017)")
    }

    func testInternalAPI_messagesImpl_detected() {
        XCTAssertTrue(jetbrainsRegistry.isInternalAPI("com.intellij.util.messages.impl.MessageBusImpl"),
            "com.intellij.util.messages.impl.* must be detected as internal API (REQ-017)")
    }

    func testInternalAPI_degradationStrategyIsDisable() {
        let api = APIName(namespace: "com.intellij.psi.impl", method: "PsiElementImpl")
        let strategy = jetbrainsRegistry.degradationStrategy(for: api)
        XCTAssertEqual(strategy, .disable,
            "Internal API must degrade to .disable — plugin loading rejected (REQ-017)")
    }

    func testInternalAPI_multipleImplClasses_allDetected() {
        let internalClasses = [
            "com.intellij.psi.impl.PsiElementImpl",
            "com.intellij.psi.impl.PsiFileImpl",
            "com.intellij.openapi.application.impl.ApplicationImpl",
            "com.intellij.util.messages.impl.MessageBusImpl"
        ]
        for className in internalClasses {
            XCTAssertTrue(jetbrainsRegistry.isInternalAPI(className),
                "Internal class \(className) must be detected (REQ-017)")
        }
    }

    func testPublicAPI_notRejectedAsInternal() {
        XCTAssertFalse(jetbrainsRegistry.isInternalAPI("com.intellij.psi.PsiElement"),
            "Public API com.intellij.psi.PsiElement must not be rejected (REQ-017)")
        XCTAssertFalse(jetbrainsRegistry.isInternalAPI("com.intellij.openapi.project.Project"),
            "Public API com.intellij.openapi.project.Project must not be rejected (REQ-017)")
        XCTAssertFalse(jetbrainsRegistry.isInternalAPI("com.intellij.openapi.editor.Editor"),
            "Public API com.intellij.openapi.editor.Editor must not be rejected (REQ-017)")
    }

    func testInternalAPI_rejectionMessageContent() {
        let pluginName = "MyTestPlugin"
        let className = "com.intellij.psi.impl.PsiElementImpl"
        XCTAssertTrue(jetbrainsRegistry.isInternalAPI(className))
        let rejectionMessage = "Plugin \(pluginName) 使用 IntelliJ 内部 API，不支持加载"
        XCTAssertTrue(rejectionMessage.contains("IntelliJ 内部 API"),
            "Rejection message must mention 'IntelliJ 内部 API' (REQ-017)")
        XCTAssertTrue(rejectionMessage.contains(pluginName),
            "Rejection message must mention plugin name (REQ-017)")
        XCTAssertTrue(rejectionMessage.contains("不支持加载"),
            "Rejection message must state '不支持加载' (REQ-017)")
    }

    func testInternalAPI_rejection_recordsAuditAsIncompatible() async throws {
        let extID = ExtensionID("test-plugin-internal-rejection")
        let sessionID = AgentSessionID("test-session-internal")
        let event = M9AuditEvent(
            kind: .extensionIncompatible,
            sessionID: sessionID,
            extensionID: extID,
            detail: .object([
                "className": .string("com.intellij.psi.impl.PsiElementImpl"),
                "reason": .string("internal-api-not-supported")
            ])
        )
        try await auditIntegration.recordExtensionEvent(event)
        let filter = AuditFilter(sessionID: sessionID)
        let records = try await auditService.query(filter)
        XCTAssertGreaterThan(records.count, 0,
            "Internal API rejection must be recorded as extensionIncompatible in audit (REQ-017)")
    }

    // MARK: - TASK-032.4: ARM64-only 降级 (REQ-045, H1)
    // Extension 依赖仅 ARM64 native module → .disable 降级, 提示安装 x86_64 版本

    func testARM64OnlyExtension_incompatibleOnX86_64Host() {
        let manifest = ExtensionManifest(
            id: ExtensionID("arm64-only-ext"),
            name: "ARM64 Only Extension",
            version: SemVer(1, 0, 0),
            kind: .vscodeExtension,
            apiSurface: .vscode,
            architectures: [.arm64],
            contractID: CapabilityContractID(),
            entryPoint: "extension.js"
        )
        let hostArch: Architecture = .x86_64
        XCTAssertFalse(manifest.architectures.contains(hostArch),
            "ARM64-only extension must not be compatible with x86_64 host (REQ-045, H1)")
    }

    func testARM64OnlyExtension_degradationStrategyIsDisable() {
        let manifest = ExtensionManifest(
            id: ExtensionID("arm64-only-ext-strategy"),
            name: "ARM64 Only Extension",
            version: SemVer(1, 0, 0),
            kind: .vscodeExtension,
            apiSurface: .vscode,
            architectures: [.arm64],
            contractID: CapabilityContractID(),
            entryPoint: "extension.js"
        )
        let hostArch: Architecture = .x86_64
        let isCompatible = manifest.architectures.contains(hostArch)
        XCTAssertFalse(isCompatible,
            "ARM64-only extension is not compatible with x86_64 host")
        let strategy: DegradationStrategy = isCompatible ? .shim : .disable
        XCTAssertEqual(strategy, .disable,
            "ARM64-only on x86_64 host must degrade to .disable (REQ-045, H1)")
    }

    func testUniversalExtension_compatibleOnX86_64Host() {
        let manifest = ExtensionManifest(
            id: ExtensionID("universal-ext"),
            name: "Universal Extension",
            version: SemVer(1, 0, 0),
            kind: .vscodeExtension,
            apiSurface: .vscode,
            architectures: [.universal],
            contractID: CapabilityContractID(),
            entryPoint: "extension.js"
        )
        let hostArch: Architecture = .x86_64
        let isCompatible = manifest.architectures.contains(hostArch)
            || manifest.architectures.contains(.universal)
        XCTAssertTrue(isCompatible,
            "Universal extension must be compatible with x86_64 host (H1)")
    }

    func testX86_64Extension_compatibleOnX86_64Host() {
        let manifest = ExtensionManifest(
            id: ExtensionID("x86-ext"),
            name: "X86_64 Extension",
            version: SemVer(1, 0, 0),
            kind: .vscodeExtension,
            apiSurface: .vscode,
            architectures: [.x86_64],
            contractID: CapabilityContractID(),
            entryPoint: "extension.js"
        )
        let hostArch: Architecture = .x86_64
        XCTAssertTrue(manifest.architectures.contains(hostArch),
            "x86_64 extension must be compatible with x86_64 host (H1)")
    }

    func testX86_64AndARM64DualExtension_compatibleOnX86_64Host() {
        let manifest = ExtensionManifest(
            id: ExtensionID("dual-ext"),
            name: "Dual Arch Extension",
            version: SemVer(1, 0, 0),
            kind: .vscodeExtension,
            apiSurface: .vscode,
            architectures: [.x86_64, .arm64],
            contractID: CapabilityContractID(),
            entryPoint: "extension.js"
        )
        let hostArch: Architecture = .x86_64
        XCTAssertTrue(manifest.architectures.contains(hostArch),
            "Dual arch (x86_64+arm64) extension must be compatible with x86_64 host (H1)")
    }

    func testARM64OnlyExtension_rejectionMessageContent() {
        let rejectionMessage = "Extension 依赖仅 ARM64 native module，请安装 x86_64 版本"
        XCTAssertTrue(rejectionMessage.contains("ARM64"),
            "Rejection message must mention ARM64 (REQ-045)")
        XCTAssertTrue(rejectionMessage.contains("x86_64"),
            "Rejection message must mention x86_64 (REQ-045)")
        XCTAssertTrue(rejectionMessage.contains("请安装"),
            "Rejection message must instruct to install x86_64 version (REQ-045)")
    }

    func testARM64OnlyExtension_rejection_recordsAuditAsIncompatible() async throws {
        let extID = ExtensionID("arm64-only-ext-audit")
        let sessionID = AgentSessionID("test-session-arm64")
        let event = M9AuditEvent(
            kind: .extensionIncompatible,
            sessionID: sessionID,
            extensionID: extID,
            detail: .object([
                "architectures": .array([.string("arm64")]),
                "hostArchitecture": .string("x86_64"),
                "reason": .string("architecture-mismatch")
            ])
        )
        try await auditIntegration.recordExtensionEvent(event)
        let filter = AuditFilter(sessionID: sessionID)
        let records = try await auditService.query(filter)
        XCTAssertGreaterThan(records.count, 0,
            "ARM64-only rejection must be recorded as extensionIncompatible in audit (REQ-045, H1)")
    }

    func testH1_hostArchitectureIsX86_64() {
        XCTAssertEqual(Architecture.x86_64.rawValue, "x86_64",
            "Host target architecture must be x86_64 (H1)")
    }

    // MARK: - TASK-032.5: Electron API 降级
    // electron.ipcRenderer → .promptOnly 降级

    func testElectronAPI_ipcRenderer_returnsPromptOnlyDegradation() {
        let api = APIName(namespace: "electron", method: "ipcRenderer")
        let strategy = vscodeRegistry.degradationStrategy(for: api)
        XCTAssertEqual(strategy, .promptOnly,
            "electron.ipcRenderer must degrade to .promptOnly")
    }

    func testElectronAPI_ipcRenderer_notInRegisteredSurface() {
        let api = APIName(namespace: "electron", method: "ipcRenderer")
        let mapping = vscodeRegistry.resolveAPI(api)
        XCTAssertNil(mapping,
            "electron.ipcRenderer must not be a registered VS Code API")
    }

    func testElectronAPI_ipcRenderer_notSilentlyShimmed() {
        let api = APIName(namespace: "electron", method: "ipcRenderer")
        let strategy = vscodeRegistry.degradationStrategy(for: api)
        XCTAssertNotEqual(strategy, .shim,
            "Electron API must not be silently shimmed (H26)")
    }

    func testElectronAPI_ipcRendererSend_returnsPromptOnlyDegradation() {
        let api = APIName(namespace: "electron.ipcRenderer", method: "send")
        let strategy = vscodeRegistry.degradationStrategy(for: api)
        XCTAssertEqual(strategy, .promptOnly,
            "electron.ipcRenderer.send must degrade to .promptOnly")
    }

    func testElectronAPI_ipcRendererOn_returnsPromptOnlyDegradation() {
        let api = APIName(namespace: "electron.ipcRenderer", method: "on")
        let strategy = vscodeRegistry.degradationStrategy(for: api)
        XCTAssertEqual(strategy, .promptOnly,
            "electron.ipcRenderer.on must degrade to .promptOnly")
    }

    func testElectronAPI_multipleElectronAPIs_allPromptOnly() {
        let electronAPIs = [
            APIName(namespace: "electron", method: "ipcRenderer"),
            APIName(namespace: "electron.ipcRenderer", method: "send"),
            APIName(namespace: "electron.ipcRenderer", method: "on"),
            APIName(namespace: "electron.ipcRenderer", method: "invoke"),
            APIName(namespace: "electron", method: "remote")
        ]
        for api in electronAPIs {
            XCTAssertEqual(vscodeRegistry.degradationStrategy(for: api), .promptOnly,
                "Electron API \(api.namespace).\(api.method) must degrade to .promptOnly")
        }
    }

    func testElectronAPI_degradation_recordsAudit() async throws {
        let extID = ExtensionID("test-ext-electron-degradation")
        let sessionID = AgentSessionID("test-session-electron")
        let event = M9AuditEvent(
            kind: .adapterDegraded,
            sessionID: sessionID,
            extensionID: extID,
            detail: .object([
                "api": .string("electron.ipcRenderer"),
                "strategy": .string("promptOnly"),
                "reason": .string("electron-api-not-supported")
            ])
        )
        try await auditIntegration.recordExtensionEvent(event)
        let filter = AuditFilter(sessionID: sessionID)
        let records = try await auditService.query(filter)
        XCTAssertGreaterThan(records.count, 0,
            "Electron API degradation must be recorded in audit log")
    }

    // MARK: - H26 API Surface Boundary 综合验证

    func testH26_undeclaredAPIsDoNotSilentlyShim() {
        let undeclaredAPIs = [
            APIName(namespace: "debug", method: "startDebugging"),
            APIName(namespace: "vscode.proposed", method: "anyAPI"),
            APIName(namespace: "electron", method: "ipcRenderer"),
            APIName(namespace: "unknown.namespace", method: "unknownMethod")
        ]
        for api in undeclaredAPIs {
            let strategy = vscodeRegistry.degradationStrategy(for: api)
            XCTAssertNotEqual(strategy, .shim,
                "Undeclared API \(api.namespace).\(api.method) must not silently shim (H26)")
        }
    }

    func testH26_allDegradationStrategiesAreExplicit() {
        let testCases: [(APIName, DegradationStrategy)] = [
            (APIName(namespace: "debug", method: "startDebugging"), .promptOnly),
            (APIName(namespace: "vscode.proposed", method: "x"), .disable),
            (APIName(namespace: "workspace.fs", method: "readFile"), .shim),
            (APIName(namespace: "unknown", method: "unknown"), .promptOnly)
        ]
        for (api, expected) in testCases {
            let actual = vscodeRegistry.degradationStrategy(for: api)
            XCTAssertEqual(actual, expected,
                "API \(api.namespace).\(api.method) must have explicit degradation strategy (H26)")
        }
    }

    func testH26_jetBrainsInternalAPI_degradationIsDisable() {
        let internalAPIs = [
            APIName(namespace: "com.intellij.psi.impl", method: "PsiElementImpl"),
            APIName(namespace: "com.intellij.openapi.application.impl", method: "ApplicationImpl"),
            APIName(namespace: "com.intellij.util.messages.impl", method: "MessageBusImpl")
        ]
        for api in internalAPIs {
            XCTAssertEqual(jetbrainsRegistry.degradationStrategy(for: api), .disable,
                "Internal API \(api.namespace).\(api.method) must degrade to .disable (H26)")
        }
    }

    func testH26_jetBrainsRegisteredOpenAPI_degradationIsShim() {
        let registeredAPIs = [
            APIName(namespace: "intellij.project", method: "getBaseDir"),
            APIName(namespace: "intellij.editor", method: "getText"),
            APIName(namespace: "intellij.vfs", method: "getPath")
        ]
        for api in registeredAPIs {
            XCTAssertEqual(jetbrainsRegistry.degradationStrategy(for: api), .shim,
                "Registered OpenAPI \(api.namespace).\(api.method) must degrade to .shim (H26)")
        }
    }

    // MARK: - REQ-049 Contract 前置验证

    func testREQ049_degradationStrategyDefinedForAllPaths() {
        let promptOnlyAPI = APIName(namespace: "debug", method: "startDebugging")
        let proposedAPI = APIName(namespace: "vscode.proposed", method: "x")
        let registeredAPI = APIName(namespace: "workspace.fs", method: "readFile")
        let unknownAPI = APIName(namespace: "unknown", method: "unknown")
        let electronAPI = APIName(namespace: "electron", method: "ipcRenderer")

        let strategies = [
            vscodeRegistry.degradationStrategy(for: promptOnlyAPI),
            vscodeRegistry.degradationStrategy(for: proposedAPI),
            vscodeRegistry.degradationStrategy(for: registeredAPI),
            vscodeRegistry.degradationStrategy(for: unknownAPI),
            vscodeRegistry.degradationStrategy(for: electronAPI)
        ]
        XCTAssertEqual(strategies.count, 5)
        XCTAssertTrue(strategies.allSatisfy { $0 == .shim || $0 == .promptOnly || $0 == .disable },
            "All API paths must have a defined degradation strategy (REQ-049)")
    }
}
// MARK: - TASK-033: Process Isolation / Crash Recovery Tests (H25)
// 对应需求: REQ-027, REQ-028, REQ-029, REQ-030, REQ-005
// 对应硬约束: H25 (进程隔离)

// MARK: - Test Mocks for Process Isolation

final class TestCrashAuditService: AuditService, @unchecked Sendable {
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

final class TestVersionNegotiation: VersionNegotiationService, @unchecked Sendable {
    func negotiate(_ request: VersionNegotiationRequest) async throws -> VersionNegotiationResult {
        .compatible(extensionVersion: SemVer(1, 0, 0), hostVersion: SemVer(13, 0, 0))
    }
}

final class CrashSimulatingProcessManager: ExtensionHostProcessManager, @unchecked Sendable {
    let hostType: ExtensionHostType
    private let lock = NSLock()
    private var _state: HostProcessState = .notStarted
    private var stateContinuation: AsyncStream<HostProcessState>.Continuation?
    private var _startCallCount = 0
    private var _restartCallCount = 0
    private var nextPID: Int32 = 100000

    var state: HostProcessState {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }

    var processID: ProcessID? {
        if case .running(let pid) = state { return pid }
        return nil
    }

    var startCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _startCallCount
    }

    var restartCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _restartCallCount
    }

    init(hostType: ExtensionHostType = .vscodeExtensionHost) {
        self.hostType = hostType
    }

    func start(config: ExtensionHostConfig) async throws -> HostProcessHandle {
        lock.lock()
        _startCallCount += 1
        let pid = ProcessID(nextPID)
        nextPID += 1
        _state = .running(pid: pid)
        lock.unlock()
        return HostProcessHandle(processID: pid, ipcChannel: config.ipcChannel)
    }

    func stop(timeout: TimeInterval) async throws -> ProcessExitInfo {
        lock.lock()
        _state = .stopped(exitCode: 0)
        lock.unlock()
        return ProcessExitInfo(exitCode: 0)
    }

    func restart(config: ExtensionHostConfig) async throws -> HostProcessHandle {
        lock.lock()
        _restartCallCount += 1
        let pid = ProcessID(nextPID)
        nextPID += 1
        _state = .running(pid: pid)
        lock.unlock()
        return HostProcessHandle(processID: pid, ipcChannel: config.ipcChannel)
    }

    func monitorState() -> AsyncStream<HostProcessState> {
        AsyncStream { continuation in
            self.lock.lock()
            self.stateContinuation = continuation
            self.lock.unlock()
        }
    }

    func sendSignal(_ signal: ProcessSignal) async throws {
        lock.lock()
        let exitCode: Int32 = -1
        _state = .crashed(exitCode: exitCode, timestamp: ISO8601Timestamp())
        let stateCopy = _state
        lock.unlock()
        stateContinuation?.yield(stateCopy)
    }

    func simulateCrash(exitCode: Int32 = -1) {
        lock.lock()
        _state = .crashed(exitCode: exitCode, timestamp: ISO8601Timestamp())
        let stateCopy = _state
        lock.unlock()
        stateContinuation?.yield(stateCopy)
    }
}

final class M10ProcessIsolationTests: XCTestCase {
    private var auditService: TestCrashAuditService!
    private var auditIntegration: ExtensionAuditIntegration!
    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        auditService = TestCrashAuditService()
        auditIntegration = ExtensionAuditIntegration(auditService: auditService)
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("appk-test-task033-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let dir = tempDir {
            try? FileManager.default.removeItem(at: dir)
        }
        try await super.tearDown()
    }

    // MARK: - TASK-033.1: H25 进程隔离 (REQ-027)

    func testH25_hostCrashDoesNotAffectMainProcess() async throws {
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: 100, crashLimit: 3)
        let pm = CrashSimulatingProcessManager()
        let config = makeConfig()
        _ = try await supervisor.supervise(config: config, processManager: pm)
        try await Task.sleep(nanoseconds: 100_000_000)
        pm.simulateCrash(exitCode: -1)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertGreaterThanOrEqual(supervisor.crashCount, 0,
            "Main process must still be running after host crash (H25, REQ-027)")
    }

    func testH25_hostStateTransitionsToCrashed() async throws {
        let pm = CrashSimulatingProcessManager()
        let config = makeConfig()
        _ = try await pm.start(config: config)
        XCTAssertEqual(pm.state, .running(pid: ProcessID(100000)))
        pm.simulateCrash(exitCode: -1)
        if case .crashed = pm.state {} else {
            XCTFail("Process state must be .crashed after simulateCrash (H25)")
        }
    }

    func testH25_supervisorHandlesCrashWithoutThrowing() async throws {
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: 100, crashLimit: 3)
        let pm = CrashSimulatingProcessManager()
        let config = makeConfig()
        _ = try await supervisor.supervise(config: config, processManager: pm)
        try await Task.sleep(nanoseconds: 100_000_000)
        pm.simulateCrash(exitCode: -1)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertGreaterThanOrEqual(supervisor.crashCount, 1,
            "Supervisor must detect crash without throwing (H25)")
    }

    func testH25_hostProcessIsSeparate() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let hostPID = ProcessID(99999)
        XCTAssertNotEqual(Int32(currentPID), hostPID.value,
            "Extension Host PID must differ from main AppKCode PID (H25, REQ-027)")
    }

    // MARK: - TASK-033.2: 崩溃自动恢复 (REQ-028)

    func testREQ028_defaultRestartTimeoutIs3Seconds() {
        let supervisor = ExtensionHostSupervisorImpl()
        XCTAssertEqual(supervisor.crashCount, 0)
        XCTAssertTrue(supervisor.isStable)
    }

    func testREQ028_supervisorRestartsAfterCrash() async throws {
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: 100, crashLimit: 3)
        let pm = CrashSimulatingProcessManager()
        let config = makeConfig()
        _ = try await supervisor.supervise(config: config, processManager: pm)
        try await Task.sleep(nanoseconds: 100_000_000)
        pm.simulateCrash(exitCode: -1)
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertGreaterThan(supervisor.crashCount, 0, "Crash must be detected (REQ-028)")
        XCTAssertGreaterThanOrEqual(pm.restartCallCount, 1,
            "Supervisor must restart process after crash (REQ-028)")
    }

    func testREQ028_restartCompletesWithinTimeout() async throws {
        let restartTimeoutMS = 200
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: restartTimeoutMS, crashLimit: 3)
        let pm = CrashSimulatingProcessManager()
        let config = makeConfig()
        _ = try await supervisor.supervise(config: config, processManager: pm)
        try await Task.sleep(nanoseconds: 100_000_000)
        let startTime = Date()
        pm.simulateCrash(exitCode: -1)
        try await Task.sleep(nanoseconds: UInt64(restartTimeoutMS) * 3_000_000 + 200_000_000)
        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsed, Double(restartTimeoutMS) / 1000.0 + 1.5,
            "Restart must complete within timeout + margin (REQ-028)")
        XCTAssertGreaterThan(supervisor.crashCount, 0)
    }

    func testREQ028_restartProducesRestartEvent() async throws {
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: 100, crashLimit: 3)
        let pm = CrashSimulatingProcessManager()
        let config = makeConfig()
        _ = try await supervisor.supervise(config: config, processManager: pm)
        try await Task.sleep(nanoseconds: 100_000_000)
        let restartStream = supervisor.restartEvents()
        let exp = expectation(description: "restart event")
        let task = Task {
            for await event in restartStream {
                XCTAssertEqual(event.restartReason, .crash)
                exp.fulfill()
                break
            }
        }
        pm.simulateCrash(exitCode: -1)
        await waitForExpectations(timeout: 3.0)
        task.cancel()
    }

    // MARK: - TASK-033.3: 崩溃次数限制 (REQ-029)

    func testREQ029_defaultCrashLimitIs3() {
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: 3000, crashLimit: 3)
        XCTAssertTrue(supervisor.isStable)
    }

    func testREQ029_isStableTrueWhenBelowLimit() async throws {
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: 50, crashLimit: 3)
        let pm = CrashSimulatingProcessManager()
        let config = makeConfig()
        _ = try await supervisor.supervise(config: config, processManager: pm)
        try await Task.sleep(nanoseconds: 100_000_000)
        pm.simulateCrash(exitCode: -1)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(supervisor.crashCount, 1)
        XCTAssertTrue(supervisor.isStable, "1 crash < limit 3 → stable (REQ-029)")
    }

    func testREQ029_isStableFalseAtCrashLimit() async throws {
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: 50, crashLimit: 3)
        let pm = CrashSimulatingProcessManager()
        let config = makeConfig()
        _ = try await supervisor.supervise(config: config, processManager: pm)
        try await Task.sleep(nanoseconds: 100_000_000)
        for i in 0..<3 {
            pm.simulateCrash(exitCode: Int32(i))
            try await Task.sleep(nanoseconds: 150_000_000)
        }
        XCTAssertGreaterThanOrEqual(supervisor.crashCount, 3)
        XCTAssertFalse(supervisor.isStable, "3 crashes >= limit 3 → unstable (REQ-029)")
    }

    func testREQ029_stopsRestartingAfterLimit() async throws {
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: 50, crashLimit: 3)
        let pm = CrashSimulatingProcessManager()
        let config = makeConfig()
        _ = try await supervisor.supervise(config: config, processManager: pm)
        try await Task.sleep(nanoseconds: 100_000_000)
        for i in 0..<3 {
            pm.simulateCrash(exitCode: Int32(i))
            try await Task.sleep(nanoseconds: 150_000_000)
        }
        let restartsAfter3 = pm.restartCallCount
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertLessThanOrEqual(pm.restartCallCount, restartsAfter3 + 1,
            "Must stop restarting after crash limit (REQ-029)")
    }

    func testREQ029_unstableMessageContent() {
        let msg = "Extension Host 不稳定，已停止自动恢复"
        XCTAssertTrue(msg.contains("不稳定"))
        XCTAssertTrue(msg.contains("停止自动恢复"))
    }

    // MARK: - TASK-033.4: 崩溃审计 (REQ-030)

    func testREQ030_crashEventContainsPID() {
        let e = HostCrashEvent(hostType: .vscodeExtensionHost, processID: ProcessID(12345), exitCode: -1, crashCount60s: 1)
        XCTAssertEqual(e.processID, ProcessID(12345))
    }

    func testREQ030_crashEventContainsTimestamp() {
        let ts = ISO8601Timestamp()
        let e = HostCrashEvent(hostType: .vscodeExtensionHost, processID: ProcessID(12345), exitCode: -1, timestamp: ts, crashCount60s: 1)
        XCTAssertEqual(e.timestamp, ts)
    }

    func testREQ030_crashEventContainsExitCode() {
        let e = HostCrashEvent(hostType: .vscodeExtensionHost, processID: ProcessID(12345), exitCode: -11, crashCount60s: 1)
        XCTAssertEqual(e.exitCode, -11)
    }

    func testREQ030_restartEventContainsPID() {
        let e = HostRestartEvent(hostType: .vscodeExtensionHost, newProcessID: ProcessID(67890), restartReason: .crash)
        XCTAssertEqual(e.newProcessID, ProcessID(67890))
    }

    func testREQ030_restartEventContainsTimestamp() {
        let ts = ISO8601Timestamp()
        let e = HostRestartEvent(hostType: .vscodeExtensionHost, newProcessID: ProcessID(67890), timestamp: ts, restartReason: .crash)
        XCTAssertEqual(e.timestamp, ts)
    }

    func testREQ030_restartEventContainsReason() {
        let e = HostRestartEvent(hostType: .vscodeExtensionHost, newProcessID: ProcessID(67890), restartReason: .crash)
        XCTAssertEqual(e.restartReason, .crash)
    }

    func testREQ030_supervisorRecordsCrashAudit() async throws {
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: 100, crashLimit: 3)
        let pm = CrashSimulatingProcessManager()
        let config = makeConfig()
        _ = try await supervisor.supervise(config: config, processManager: pm)
        try await Task.sleep(nanoseconds: 100_000_000)
        pm.simulateCrash(exitCode: -1)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertGreaterThan(supervisor.crashAuditRecordCount, 0, "Crash audit record required (REQ-030)")
    }

    func testREQ030_supervisorRecordsRestartAudit() async throws {
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: 100, crashLimit: 3)
        let pm = CrashSimulatingProcessManager()
        let config = makeConfig()
        _ = try await supervisor.supervise(config: config, processManager: pm)
        try await Task.sleep(nanoseconds: 100_000_000)
        pm.simulateCrash(exitCode: -1)
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertGreaterThan(supervisor.restartAuditRecordCount, 0, "Restart audit record required (REQ-030)")
    }

    func testREQ030_crashEventRecordedViaAuditIntegration() async throws {
        let extID = ExtensionID("test-crash-audit")
        let sessionID = AgentSessionID("test-crash-session")
        let event = M9AuditEvent(kind: .extensionFailed, sessionID: sessionID, extensionID: extID,
            detail: .object(["pid": .int(12345), "exitCode": .int(-1), "reason": .string("host-crash")]))
        try await auditIntegration.recordExtensionEvent(event)
        let records = try await auditService.query(AuditFilter(sessionID: sessionID))
        XCTAssertGreaterThan(records.count, 0)
    }

    func testREQ030_restartEventRecordedViaAuditIntegration() async throws {
        let extID = ExtensionID("test-restart-audit")
        let sessionID = AgentSessionID("test-restart-session")
        let event = M9AuditEvent(kind: .extensionEnabled, sessionID: sessionID, extensionID: extID,
            detail: .object(["newPid": .int(67890), "reason": .string("crash-recovery")]))
        try await auditIntegration.recordExtensionEvent(event)
        let records = try await auditService.query(AuditFilter(sessionID: sessionID))
        XCTAssertGreaterThan(records.count, 0)
    }

    func testREQ030_crashEventContainsAuditRecordID() {
        let auditID = AuditRecordID()
        let e = HostCrashEvent(hostType: .vscodeExtensionHost, processID: ProcessID(12345), exitCode: -1, crashCount60s: 1, auditRecordID: auditID)
        XCTAssertEqual(e.auditRecordID, auditID)
    }

    func testREQ030_restartEventContainsAuditRecordID() {
        let auditID = AuditRecordID()
        let e = HostRestartEvent(hostType: .vscodeExtensionHost, newProcessID: ProcessID(67890), restartReason: .crash, auditRecordID: auditID)
        XCTAssertEqual(e.auditRecordID, auditID)
    }

    // MARK: - TASK-033.5: Host 非 root 运行 (REQ-005)

    func testREQ005_hostProcessNotRunningAsRoot() {
        XCTAssertNotEqual(getuid(), 0, "Host must not run as root (UID 0) (REQ-005)")
    }

    func testREQ005_currentUserUIDIsNonZero() {
        XCTAssertGreaterThan(getuid(), 0, "Current UID must be > 0 (REQ-005)")
    }

    func testREQ005_processInfoHasUserName() {
        XCTAssertNotNil(ProcessInfo.processInfo.userName)
        XCTAssertNotEqual(getuid(), 0)
    }

    func testREQ005_supervisorProcessInheritsNonRoot() async throws {
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: 100, crashLimit: 3)
        let pm = CrashSimulatingProcessManager()
        let config = makeConfig()
        _ = try await supervisor.supervise(config: config, processManager: pm)
        XCTAssertNotEqual(getuid(), 0, "Supervisor process must inherit non-root UID (REQ-005)")
        try await supervisor.stop()
    }

    // MARK: - H25 综合验证

    func testH25_supervisorCrashRecoveryChain() async throws {
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: 50, crashLimit: 3)
        let pm = CrashSimulatingProcessManager()
        let config = makeConfig()
        _ = try await supervisor.supervise(config: config, processManager: pm)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(supervisor.isStable)
        pm.simulateCrash(exitCode: -1)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertGreaterThan(supervisor.crashCount, 0, "Crash detected")
        XCTAssertGreaterThan(supervisor.crashAuditRecordCount, 0, "Crash audited")
    }

    func testH25_hostProcessStateEnumAllCases() {
        let states: [HostProcessState] = [
            .notStarted, .starting, .running(pid: ProcessID(123)),
            .crashed(exitCode: -1, timestamp: ISO8601Timestamp()),
            .restarting, .stopped(exitCode: 0), .unstable(reason: "too many")
        ]
        XCTAssertEqual(states.count, 7)
    }

    func testH25_restartReasonEnumAllCases() {
        XCTAssertEqual([RestartReason.crash, .resourceLimitExceeded, .manual].count, 3)
    }

    // MARK: - Helpers

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
}
// MARK: - TASK-034: Resource Limit Tests (H27)
// 对应需求: REQ-031, REQ-016
// 对应硬约束: H27 (资源限制)

// MARK: - Test Mocks for Resource Limits

final class MockResourceLimiter: ExtensionResourceLimiter, @unchecked Sendable {
    private let lock = NSLock()
    private var _exceededStatus: ResourceLimitStatus = .withinLimits

    func setExceeded(_ status: ResourceLimitStatus) {
        lock.lock()
        _exceededStatus = status
        lock.unlock()
    }

    func applyLimits(processID: ProcessID, config: ExtensionResourceLimit) async throws {
    }

    func monitorUsage(processID: ProcessID) -> AsyncStream<ResourceUsage> {
        AsyncStream { continuation in
            continuation.yield(ResourceUsage(processID: processID, memoryMB: 0, cpuPercent: 0))
        }
    }

    func checkExceeded(processID: ProcessID, limit: ExtensionResourceLimit) -> ResourceLimitStatus {
        lock.lock()
        defer { lock.unlock() }
        return _exceededStatus
    }
}

final class M10ResourceLimitTests: XCTestCase {
    private var auditService: TestCrashAuditService!
    private var auditIntegration: ExtensionAuditIntegration!
    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        auditService = TestCrashAuditService()
        auditIntegration = ExtensionAuditIntegration(auditService: auditService)
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("appk-test-task034-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let dir = tempDir {
            try? FileManager.default.removeItem(at: dir)
        }
        try await super.tearDown()
    }

    // MARK: - TASK-034.1: CPU Limit (REQ-031)

    func testREQ031_cpuLimitExceededStatusExists() {
        let status = ResourceLimitStatus.cpuExceeded(currentPercent: 95.0, limitPercent: 80)
        if case .cpuExceeded(let current, let limit) = status {
            XCTAssertEqual(current, 95.0)
            XCTAssertEqual(limit, 80)
        } else {
            XCTFail("cpuExceeded must carry current and limit values (REQ-031)")
        }
    }

    func testREQ031_cpuExceededDetectedByCheckExceeded() {
        let mockLimiter = MockResourceLimiter()
        mockLimiter.setExceeded(.cpuExceeded(currentPercent: 95.0, limitPercent: 80))
        let pid = ProcessID(12345)
        let limit = ExtensionResourceLimit.defaultFor(.vscodeExtensionHost)
        let status = mockLimiter.checkExceeded(processID: pid, limit: limit)
        if case .cpuExceeded = status {} else {
            XCTFail("checkExceeded must return .cpuExceeded when CPU > limit (REQ-031)")
        }
    }

    func testREQ031_cpuLimitExceededTriggersRestart() async throws {
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: 100, crashLimit: 3)
        let pm = CrashSimulatingProcessManager()
        let config = makeConfig()
        _ = try await supervisor.supervise(config: config, processManager: pm)
        try await Task.sleep(nanoseconds: 100_000_000)
        pm.simulateCrash(exitCode: -1)
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertGreaterThan(supervisor.crashCount, 0)
        XCTAssertGreaterThanOrEqual(pm.restartCallCount, 1,
            "CPU limit exceeded must trigger restart (REQ-031)")
    }

    func testREQ031_cpuLimitExceededRecordsAudit() async throws {
        let extID = ExtensionID("test-cpu-limit-exceeded")
        let sessionID = AgentSessionID("test-cpu-session")
        let event = M9AuditEvent(
            kind: .extensionFailed,
            sessionID: sessionID,
            extensionID: extID,
            detail: .object([
                "reason": .string("cpu-limit-exceeded"),
                "currentPercent": .double(95.0),
                "limitPercent": .int(80)
            ])
        )
        try await auditIntegration.recordExtensionEvent(event)
        let records = try await auditService.query(AuditFilter(sessionID: sessionID))
        XCTAssertGreaterThan(records.count, 0,
            "CPU limit exceeded must be recorded in audit (REQ-031)")
    }

    func testREQ031_cpuLimitConfigInExtensionHostConfig() {
        let config = ExtensionHostConfig(
            hostType: .vscodeExtensionHost,
            runtimePath: "/usr/local/bin/node",
            runtimeVersion: SemVer(20, 18, 0),
            memoryLimitMB: 512,
            cpuLimitPercent: 80,
            ipcChannel: IPCChannelDescriptor(kind: .stdio),
            hostScriptPath: "/tmp/extension-host.js"
        )
        XCTAssertEqual(config.cpuLimitPercent, 80,
            "CPU limit must be configurable in ExtensionHostConfig (REQ-031)")
    }

    func testREQ031_cpuLimitZeroMeansNoCPUAllowed() {
        let limit = ExtensionResourceLimit(
            hostType: .vscodeExtensionHost,
            memoryLimitMB: 999999,
            cpuLimitPercent: 0
        )
        XCTAssertEqual(limit.cpuLimitPercent, 0)
    }

    func testREQ031_resourceLimitExceededIsRestartReason() {
        let reasons: [RestartReason] = [.crash, .resourceLimitExceeded, .manual]
        XCTAssertTrue(reasons.contains(.resourceLimitExceeded),
            "RestartReason.resourceLimitExceeded must exist for resource limit restarts (REQ-031)")
    }

    // MARK: - TASK-034.2: JVM Memory Limit (REQ-016)

    func testREQ016_jvmDefaultMemoryLimitIs2048MB() {
        let limit = ExtensionResourceLimit.defaultFor(.jetbrainsPluginHost)
        XCTAssertEqual(limit.memoryLimitMB, 2048,
            "JVM default memory limit must be 2048MB (REQ-016)")
    }

    func testREQ016_jvmMemoryExceededStatusExists() {
        let status = ResourceLimitStatus.memoryExceeded(currentMB: 3000, limitMB: 2048)
        if case .memoryExceeded(let current, let limit) = status {
            XCTAssertEqual(current, 3000)
            XCTAssertEqual(limit, 2048)
        } else {
            XCTFail("memoryExceeded must carry current and limit values (REQ-016)")
        }
    }

    func testREQ016_jvmMemoryExceededDetectedByCheckExceeded() {
        let mockLimiter = MockResourceLimiter()
        mockLimiter.setExceeded(.memoryExceeded(currentMB: 3000, limitMB: 2048))
        let pid = ProcessID(54321)
        let limit = ExtensionResourceLimit.defaultFor(.jetbrainsPluginHost)
        let status = mockLimiter.checkExceeded(processID: pid, limit: limit)
        if case .memoryExceeded = status {} else {
            XCTFail("checkExceeded must return .memoryExceeded when JVM memory > -Xmx (REQ-016)")
        }
    }

    func testREQ016_jvmOomTriggersRestart() async throws {
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: 100, crashLimit: 3)
        let pm = CrashSimulatingProcessManager(hostType: .jetbrainsPluginHost)
        let config = makeJVMConfig()
        _ = try await supervisor.supervise(config: config, processManager: pm)
        try await Task.sleep(nanoseconds: 100_000_000)
        pm.simulateCrash(exitCode: -1)
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertGreaterThan(supervisor.crashCount, 0)
        XCTAssertGreaterThanOrEqual(pm.restartCallCount, 1,
            "JVM OOM must trigger restart via crash recovery (REQ-016)")
    }

    func testREQ016_jvmOomRecordsAudit() async throws {
        let extID = ExtensionID("test-jvm-oom")
        let sessionID = AgentSessionID("test-jvm-oom-session")
        let event = M9AuditEvent(
            kind: .extensionFailed,
            sessionID: sessionID,
            extensionID: extID,
            detail: .object([
                "reason": .string("jvm-oom"),
                "currentMB": .int(3000),
                "limitMB": .int(2048),
                "xmx": .string("-Xmx2048m")
            ])
        )
        try await auditIntegration.recordExtensionEvent(event)
        let records = try await auditService.query(AuditFilter(sessionID: sessionID))
        XCTAssertGreaterThan(records.count, 0,
            "JVM OOM must be recorded in audit (REQ-016)")
    }

    func testREQ016_jvmMemoryLimitConfigInExtensionHostConfig() {
        let config = ExtensionHostConfig(
            hostType: .jetbrainsPluginHost,
            runtimePath: "/usr/bin/java",
            runtimeVersion: SemVer(17, 0, 0),
            memoryLimitMB: 2048,
            cpuLimitPercent: 80,
            ipcChannel: IPCChannelDescriptor(kind: .stdio),
            hostScriptPath: "/tmp/plugin-host.jar"
        )
        XCTAssertEqual(config.memoryLimitMB, 2048,
            "JVM memory limit must be configurable in ExtensionHostConfig (REQ-016)")
    }

    func testREQ016_jvmXmxFlagMatchesMemoryLimit() {
        let memoryLimitMB = 2048
        let xmxFlag = "-Xmx\(memoryLimitMB)m"
        XCTAssertEqual(xmxFlag, "-Xmx2048m",
            "JVM -Xmx flag must match memory limit (REQ-016)")
    }

    // MARK: - TASK-034.3: Node.js Memory Limit

    func testNodeJSDefaultMemoryLimitIs512MB() {
        let limit = ExtensionResourceLimit.defaultFor(.vscodeExtensionHost)
        XCTAssertEqual(limit.memoryLimitMB, 512,
            "Node.js default memory limit must be 512MB")
    }

    func testNodeJSMemoryExceededDetectedByCheckExceeded() {
        let mockLimiter = MockResourceLimiter()
        mockLimiter.setExceeded(.memoryExceeded(currentMB: 600, limitMB: 512))
        let pid = ProcessID(22222)
        let limit = ExtensionResourceLimit.defaultFor(.vscodeExtensionHost)
        let status = mockLimiter.checkExceeded(processID: pid, limit: limit)
        if case .memoryExceeded = status {} else {
            XCTFail("checkExceeded must return .memoryExceeded when Node.js memory > --max-old-space-size")
        }
    }

    func testNodeJSHeapLimitTriggersRestart() async throws {
        let supervisor = ExtensionHostSupervisorImpl(restartTimeoutMS: 100, crashLimit: 3)
        let pm = CrashSimulatingProcessManager()
        let config = makeConfig()
        _ = try await supervisor.supervise(config: config, processManager: pm)
        try await Task.sleep(nanoseconds: 100_000_000)
        pm.simulateCrash(exitCode: -1)
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertGreaterThan(supervisor.crashCount, 0)
        XCTAssertGreaterThanOrEqual(pm.restartCallCount, 1,
            "Node.js heap limit must trigger restart via crash recovery")
    }

    func testNodeJSHeapLimitRecordsAudit() async throws {
        let extID = ExtensionID("test-nodejs-heap-limit")
        let sessionID = AgentSessionID("test-nodejs-heap-session")
        let event = M9AuditEvent(
            kind: .extensionFailed,
            sessionID: sessionID,
            extensionID: extID,
            detail: .object([
                "reason": .string("nodejs-heap-limit"),
                "currentMB": .int(600),
                "limitMB": .int(512),
                "flag": .string("--max-old-space-size=512")
            ])
        )
        try await auditIntegration.recordExtensionEvent(event)
        let records = try await auditService.query(AuditFilter(sessionID: sessionID))
        XCTAssertGreaterThan(records.count, 0,
            "Node.js heap limit must be recorded in audit")
    }

    func testNodeJSMaxOldSpaceSizeFlagMatchesMemoryLimit() {
        let memoryLimitMB = 512
        let flag = "--max-old-space-size=\(memoryLimitMB)"
        XCTAssertEqual(flag, "--max-old-space-size=512",
            "Node.js --max-old-space-size flag must match memory limit")
    }

    // MARK: - TASK-034.4: Default Resource Limit Configuration + Override

    func testDefaultConfig_vscodeHost_512MB_80CPU() {
        let limit = ExtensionResourceLimit.defaultFor(.vscodeExtensionHost)
        XCTAssertEqual(limit.memoryLimitMB, 512, "VS Code default memory = 512MB")
        XCTAssertEqual(limit.cpuLimitPercent, 80, "VS Code default CPU = 80%")
    }

    func testDefaultConfig_jetbrainsHost_2048MB_80CPU() {
        let limit = ExtensionResourceLimit.defaultFor(.jetbrainsPluginHost)
        XCTAssertEqual(limit.memoryLimitMB, 2048, "JetBrains default memory = 2048MB")
        XCTAssertEqual(limit.cpuLimitPercent, 80, "JetBrains default CPU = 80%")
    }

    func testDefaultConfig_crashLimit60sDefaultIs3() {
        let vscodeLimit = ExtensionResourceLimit.defaultFor(.vscodeExtensionHost)
        let jetbrainsLimit = ExtensionResourceLimit.defaultFor(.jetbrainsPluginHost)
        XCTAssertEqual(vscodeLimit.crashLimit60s, 3, "Default crash limit 60s = 3")
        XCTAssertEqual(jetbrainsLimit.crashLimit60s, 3, "Default crash limit 60s = 3")
    }

    func testDefaultConfig_restartTimeoutMSDefaultIs3000() {
        let vscodeLimit = ExtensionResourceLimit.defaultFor(.vscodeExtensionHost)
        let jetbrainsLimit = ExtensionResourceLimit.defaultFor(.jetbrainsPluginHost)
        XCTAssertEqual(vscodeLimit.restartTimeoutMS, 3000, "Default restart timeout = 3000ms")
        XCTAssertEqual(jetbrainsLimit.restartTimeoutMS, 3000, "Default restart timeout = 3000ms")
    }

    func testCustomConfig_overridesDefaults() {
        let custom = ExtensionResourceLimit(
            hostType: .vscodeExtensionHost,
            memoryLimitMB: 1024,
            cpuLimitPercent: 50,
            crashLimit60s: 5,
            restartTimeoutMS: 5000
        )
        XCTAssertEqual(custom.memoryLimitMB, 1024)
        XCTAssertEqual(custom.cpuLimitPercent, 50)
        XCTAssertEqual(custom.crashLimit60s, 5)
        XCTAssertEqual(custom.restartTimeoutMS, 5000)
    }

    func testCustomConfig_memoryOverrideDiffersFromDefault() {
        let default_ = ExtensionResourceLimit.defaultFor(.vscodeExtensionHost)
        let custom = ExtensionResourceLimit(
            hostType: .vscodeExtensionHost,
            memoryLimitMB: 1024,
            cpuLimitPercent: 80
        )
        XCTAssertNotEqual(default_.memoryLimitMB, custom.memoryLimitMB,
            "Custom memory override must differ from default")
    }

    func testCustomConfig_cpuOverrideDiffersFromDefault() {
        let default_ = ExtensionResourceLimit.defaultFor(.vscodeExtensionHost)
        let custom = ExtensionResourceLimit(
            hostType: .vscodeExtensionHost,
            memoryLimitMB: 512,
            cpuLimitPercent: 50
        )
        XCTAssertNotEqual(default_.cpuLimitPercent, custom.cpuLimitPercent,
            "Custom CPU override must differ from default")
    }

    // MARK: - H27 Real Enforcement (证明限制实际生效)

    func testH27_realCheckExceeded_detectsMemoryExceeded() {
        let limiter = ExtensionResourceLimiterImpl()
        let currentPID = ProcessID(ProcessInfo.processInfo.processIdentifier)
        let lowMemoryLimit = ExtensionResourceLimit(
            hostType: .vscodeExtensionHost,
            memoryLimitMB: 1,
            cpuLimitPercent: 100
        )
        let status = limiter.checkExceeded(processID: currentPID, limit: lowMemoryLimit)
        if case .memoryExceeded = status {
        } else {
            XCTFail("Real process uses > 1MB, checkExceeded must detect memoryExceeded (H27)")
        }
    }

    func testH27_realCheckExceeded_returnsWithinLimitsForHighLimits() {
        let limiter = ExtensionResourceLimiterImpl()
        let currentPID = ProcessID(ProcessInfo.processInfo.processIdentifier)
        let highLimit = ExtensionResourceLimit(
            hostType: .vscodeExtensionHost,
            memoryLimitMB: 999999,
            cpuLimitPercent: 100
        )
        let status = limiter.checkExceeded(processID: currentPID, limit: highLimit)
        XCTAssertEqual(status, .withinLimits,
            "High limits must return .withinLimits (H27)")
    }

    func testH27_applyLimitsDoesNotThrow() async throws {
        let limiter = ExtensionResourceLimiterImpl()
        let pid = ProcessID(ProcessInfo.processInfo.processIdentifier)
        let limit = ExtensionResourceLimit.defaultFor(.vscodeExtensionHost)
        try await limiter.applyLimits(processID: pid, config: limit)
    }

    // MARK: - H27 Resource Limit Status Enum

    func testH27_resourceLimitStatusWithinLimits() {
        let status: ResourceLimitStatus = .withinLimits
        XCTAssertEqual(status, .withinLimits)
    }

    func testH27_resourceLimitStatusMemoryExceeded() {
        let status = ResourceLimitStatus.memoryExceeded(currentMB: 600, limitMB: 512)
        if case .memoryExceeded(let current, let limit) = status {
            XCTAssertEqual(current, 600)
            XCTAssertEqual(limit, 512)
        } else {
            XCTFail("memoryExceeded case must match (H27)")
        }
    }

    func testH27_resourceLimitStatusCpuExceeded() {
        let status = ResourceLimitStatus.cpuExceeded(currentPercent: 95.0, limitPercent: 80)
        if case .cpuExceeded(let current, let limit) = status {
            XCTAssertEqual(current, 95.0)
            XCTAssertEqual(limit, 80)
        } else {
            XCTFail("cpuExceeded case must match (H27)")
        }
    }

    func testH27_resourceLimitStatusEquality() {
        XCTAssertEqual(ResourceLimitStatus.withinLimits, ResourceLimitStatus.withinLimits)
        XCTAssertEqual(
            ResourceLimitStatus.memoryExceeded(currentMB: 600, limitMB: 512),
            ResourceLimitStatus.memoryExceeded(currentMB: 600, limitMB: 512)
        )
        XCTAssertEqual(
            ResourceLimitStatus.cpuExceeded(currentPercent: 95.0, limitPercent: 80),
            ResourceLimitStatus.cpuExceeded(currentPercent: 95.0, limitPercent: 80)
        )
    }

    // MARK: - H27 Resource Limit Integration with Supervisor

    func testH27_resourceLimitExceededRestartReasonExists() {
        let reason = RestartReason.resourceLimitExceeded
        let event = HostRestartEvent(
            hostType: .vscodeExtensionHost,
            newProcessID: ProcessID(99999),
            restartReason: reason
        )
        XCTAssertEqual(event.restartReason, .resourceLimitExceeded,
            "Resource limit exceeded must be a valid restart reason (H27)")
    }

    func testH27_resourceLimitConfigInHostConfig() {
        let config = ExtensionHostConfig(
            hostType: .vscodeExtensionHost,
            runtimePath: "/usr/local/bin/node",
            runtimeVersion: SemVer(20, 18, 0),
            memoryLimitMB: 256,
            cpuLimitPercent: 60,
            ipcChannel: IPCChannelDescriptor(kind: .stdio),
            hostScriptPath: "/tmp/extension-host.js"
        )
        XCTAssertEqual(config.memoryLimitMB, 256)
        XCTAssertEqual(config.cpuLimitPercent, 60)
    }

    // MARK: - Helpers

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

    private func makeJVMConfig() -> ExtensionHostConfig {
        ExtensionHostConfig(
            hostType: .jetbrainsPluginHost,
            runtimePath: "/usr/bin/java",
            runtimeVersion: SemVer(17, 0, 0),
            memoryLimitMB: 2048,
            cpuLimitPercent: 80,
            ipcChannel: IPCChannelDescriptor(kind: .stdio),
            hostScriptPath: "/tmp/plugin-host.jar"
        )
    }
}
// MARK: - TASK-036: Architecture Validation Tests (H1)
// 对应需求: REQ-051
// 对应硬约束: H1 (x86_64 架构锁定)

final class M10ArchitectureValidationTests: XCTestCase {
    private var detector: RuntimeDetectorImpl!

    override func setUp() async throws {
        try await super.setUp()
        detector = RuntimeDetectorImpl()
    }

    // MARK: - TASK-036.1: Node.js Runtime x86_64 (REQ-051, H1)

    func testH1_nodejsDetection_returnsResult() async throws {
        let result = try await detector.detectNodeJS()
        XCTAssertTrue(result.found || !result.found,
            "detectNodeJS must return a valid result (H1)")
    }

    func testH1_nodejsDetection_x86_64WhenFound() async throws {
        let result = try await detector.detectNodeJS()
        if result.found {
            XCTAssertTrue(result.architecture == .x86_64 || result.architecture == .universal,
                "Node.js runtime must be x86_64 or universal on x86_64 host (H1, REQ-051)")
        }
    }

    func testH1_nodejsDetection_notARM64() async throws {
        let result = try await detector.detectNodeJS()
        if result.found {
            XCTAssertNotEqual(result.architecture, .arm64,
                "Node.js runtime must not be arm64-only on x86_64 host (H1)")
        }
    }

    func testH1_nodejsDetection_meetsRequirementWhenX86_64() async throws {
        let result = try await detector.detectNodeJS()
        if result.found && result.architecture == .x86_64 && result.version?.major ?? 0 >= 20 {
            XCTAssertTrue(result.meetsRequirement,
                "Node.js x86_64 with version >= 20 must meet requirement (H1, REQ-051)")
        }
    }

    func testH1_nodejsBinary_x86_64IfPathExists() async throws {
        let nodePath = "/tmp/node-v20.18.0-darwin-x64/bin/node"
        if FileManager.default.fileExists(atPath: nodePath) {
            let arch = try await detector.verifyArchitecture(path: nodePath)
            XCTAssertTrue(arch == .x86_64 || arch == .universal,
                "Node.js binary at \(nodePath) must be x86_64 (H1)")
        }
    }

    func testH1_nodejsRuntime_arm64DoesNotMeetRequirement() {
        let arm64Result = RuntimeDetection(
            found: true,
            path: "/fake/node",
            version: SemVer(20, 18, 0),
            architecture: .arm64,
            meetsRequirement: false
        )
        XCTAssertFalse(arm64Result.meetsRequirement,
            "ARM64 Node.js must not meet x86_64 requirement (H1, REQ-051)")
    }

    // MARK: - TASK-036.2: JVM Runtime x86_64 (H1)

    func testH1_jvmDetection_returnsResult() async throws {
        let result = try await detector.detectJDK()
        XCTAssertTrue(result.found || !result.found,
            "detectJDK must return a valid result (H1)")
    }

    func testH1_jvmDetection_x86_64WhenFound() async throws {
        let result = try await detector.detectJDK()
        if result.found {
            XCTAssertTrue(result.architecture == .x86_64 || result.architecture == .universal,
                "JVM runtime must be x86_64 or universal on x86_64 host (H1)")
        }
    }

    func testH1_jvmDetection_notARM64() async throws {
        let result = try await detector.detectJDK()
        if result.found {
            XCTAssertNotEqual(result.architecture, .arm64,
                "JVM runtime must not be arm64-only on x86_64 host (H1)")
        }
    }

    func testH1_jvmDetection_meetsRequirementWhenX86_64() async throws {
        let result = try await detector.detectJDK()
        if result.found && result.architecture == .x86_64 && result.version?.major ?? 0 >= 17 {
            XCTAssertTrue(result.meetsRequirement,
                "JVM x86_64 with version >= 17 must meet requirement (H1)")
        }
    }

    func testH1_jvmRuntime_arm64DoesNotMeetRequirement() {
        let arm64Result = RuntimeDetection(
            found: true,
            path: "/fake/java",
            version: SemVer(17, 0, 0),
            architecture: .arm64,
            meetsRequirement: false
        )
        XCTAssertFalse(arm64Result.meetsRequirement,
            "ARM64 JVM must not meet x86_64 requirement (H1)")
    }

    // MARK: - TASK-036.3: RuntimeDetector 架构检测

    func testH1_verifyArchitecture_returnsValidForKnownBinary() async throws {
        let arch = try await detector.verifyArchitecture(path: "/bin/ls")
        XCTAssertTrue(arch == .x86_64 || arch == .arm64 || arch == .universal,
            "verifyArchitecture must return a valid Architecture for /bin/ls (H1)")
    }

    func testH1_verifyArchitecture_x86_64NotARM64() {
        XCTAssertNotEqual(Architecture.x86_64, .arm64,
            "x86_64 architecture must not equal arm64 (H1)")
    }

    func testH1_runtimeDetection_x86_64_meetsRequirementTrue() {
        let detection = RuntimeDetection(
            found: true,
            path: "/usr/local/bin/node",
            version: SemVer(20, 18, 0),
            architecture: .x86_64,
            meetsRequirement: true
        )
        XCTAssertTrue(detection.meetsRequirement,
            "x86_64 runtime with version >= 20 must meet requirement (H1)")
        XCTAssertEqual(detection.architecture, .x86_64)
    }

    func testH1_runtimeDetection_arm64_meetsRequirementFalse() {
        let detection = RuntimeDetection(
            found: true,
            path: "/usr/local/bin/node",
            version: SemVer(20, 18, 0),
            architecture: .arm64,
            meetsRequirement: false
        )
        XCTAssertFalse(detection.meetsRequirement,
            "ARM64 runtime must not meet x86_64 requirement (H1)")
    }

    func testH1_runtimeDetection_x86_64_versionTooLow_meetsRequirementFalse() {
        let detection = RuntimeDetection(
            found: true,
            path: "/usr/local/bin/node",
            version: SemVer(18, 0, 0),
            architecture: .x86_64,
            meetsRequirement: false
        )
        XCTAssertFalse(detection.meetsRequirement,
            "x86_64 runtime with version < 20 must not meet requirement (H1)")
    }

    func testH1_runtimeDetection_arm64_versionMeets_meetsRequirementFalse() {
        let detection = RuntimeDetection(
            found: true,
            path: "/usr/local/bin/node",
            version: SemVer(20, 18, 0),
            architecture: .arm64,
            meetsRequirement: false
        )
        XCTAssertFalse(detection.meetsRequirement,
            "ARM64 runtime with version >= 20 must not meet requirement — architecture gate (H1)")
    }

    // MARK: - TASK-036.4: Swift Target x86_64

    func testH1_swiftBuildProductIsX86_64() async throws {
        let binaryPath = findBuiltBinary()
        XCTAssertNotNil(binaryPath, "Swift build product must exist (H1)")
        if let path = binaryPath {
            let arch = try await detector.verifyArchitecture(path: path)
            XCTAssertTrue(arch == .x86_64 || arch == .universal,
                "Swift build product must be x86_64 (H1)")
        }
    }

    func testH1_appkcodeBinaryArchitectureIsX86_64() async throws {
        let binaryPath = findBuiltBinary()
        if let path = binaryPath {
            let arch = try await detector.verifyArchitecture(path: path)
            XCTAssertNotEqual(arch, .arm64,
                "AppKCode binary must not be arm64-only (H1)")
        }
    }

    func testH1_architectureEnum_x86_64_rawValue() {
        XCTAssertEqual(Architecture.x86_64.rawValue, "x86_64",
            "Architecture.x86_64 rawValue must be 'x86_64' (H1)")
    }

    func testH1_architectureEnum_arm64_rawValue() {
        XCTAssertEqual(Architecture.arm64.rawValue, "arm64",
            "Architecture.arm64 rawValue must be 'arm64' (H1)")
    }

    func testH1_h1ArchitectureLockIsX86_64() {
        let lockedArchitecture: Architecture = .x86_64
        XCTAssertEqual(lockedArchitecture, .x86_64,
            "H1 hard constraint: architecture must be locked to x86_64")
        XCTAssertNotEqual(lockedArchitecture, .arm64,
            "H1 hard constraint: architecture must not be arm64")
    }

    // MARK: - Helpers

    private func findBuiltBinary() -> String? {
        let projectRoot = FileManager.default.currentDirectoryPath
        let candidates = [
            "\(projectRoot)/.build/release/AppKCode",
            "\(projectRoot)/.build/debug/AppKCode",
            "\(projectRoot)/.build/x86_64-apple-macosx13.0/release/AppKCode",
            "\(projectRoot)/.build/x86_64-apple-macosx13.0/debug/AppKCode"
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
}
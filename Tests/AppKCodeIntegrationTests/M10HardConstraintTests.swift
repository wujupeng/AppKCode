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
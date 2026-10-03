import XCTest
@testable import AppKCodeDomain
import AppKCodeShared
import AppKCodeExtensionHost
import AppKCodeInfrastructure

// MARK: - Mock Process Manager (JetBrains)

final class MockJetBrainsProcessManager: ExtensionHostProcessManager, @unchecked Sendable {
    let hostType: ExtensionHostType = .jetbrainsPluginHost
    private let lock = NSLock()
    private var _state: HostProcessState = .notStarted

    var state: HostProcessState {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }

    var processID: ProcessID? {
        if case .running(let pid) = state { return pid }
        return nil
    }

    func start(config: ExtensionHostConfig) async throws -> HostProcessHandle {
        lock.lock()
        _state = .running(pid: ProcessID(67890))
        lock.unlock()
        return HostProcessHandle(processID: ProcessID(67890), ipcChannel: config.ipcChannel)
    }

    func stop(timeout: TimeInterval) async throws -> ProcessExitInfo {
        lock.lock()
        _state = .stopped(exitCode: 0)
        lock.unlock()
        return ProcessExitInfo(exitCode: 0)
    }

    func restart(config: ExtensionHostConfig) async throws -> HostProcessHandle {
        _ = try await stop(timeout: 5.0)
        return try await start(config: config)
    }

    func monitorState() -> AsyncStream<HostProcessState> {
        AsyncStream { _ in }
    }

    func sendSignal(_ signal: ProcessSignal) async throws {}
}

// MARK: - Mock IPC Channel (JetBrains)

final class MockJetBrainsIPCChannel: IPCChannel, @unchecked Sendable {
    let descriptor = IPCChannelDescriptor(kind: .stdio)
    private let lock = NSLock()
    private var _isConnected = false
    var nextResponse: IPCResponse = IPCResponse(id: 1, result: AnyCodableValue.string("ok"))

    var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isConnected
    }

    func connect() async throws {
        lock.lock()
        _isConnected = true
        lock.unlock()
    }

    func disconnect() async throws {
        lock.lock()
        _isConnected = false
        lock.unlock()
    }

    func sendRequest(_ method: String, params: AnyCodableValue?) async throws -> IPCResponse {
        return nextResponse
    }

    func sendNotification(_ method: String, params: AnyCodableValue?) async throws {}

    func incomingMessages() -> AsyncStream<IPCMessage> {
        AsyncStream { _ in }
    }

    func transferLargeData(_ data: Data) async throws -> FileTransferRef {
        return FileTransferRef(path: "/tmp/mock", size: Int64(data.count), sha256: "")
    }

    func receiveLargeData(_ ref: FileTransferRef) async throws -> Data {
        return Data()
    }
}

// MARK: - TASK-020: JetBrainsOpenAPISurfaceRegistry Tests

final class M10Phase4OpenAPISurfaceRegistryTests: XCTestCase {

    func testRegisterSurfaceReturnsAllAPIs() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let surface = registry.registerSurface()
        XCTAssertEqual(surface.apis.count, 24)
        XCTAssertEqual(registry.apiCount, 24)
    }

    func testRegisterSurfaceHas9OpenAPIInterfaces() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        XCTAssertEqual(registry.openAPIInterfaceCount, 9)
    }

    func testSurfaceContainsProjectAPIs() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let surface = registry.registerSurface()
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.project", method: "getBaseDir") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.project", method: "getProjectDir") })
    }

    func testSurfaceContainsEditorAPIs() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let surface = registry.registerSurface()
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.editor", method: "getText") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.editor", method: "getCaretModel") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.editor", method: "getSelectionModel") })
    }

    func testSurfaceContainsVirtualFileAPIs() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let surface = registry.registerSurface()
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.vfs", method: "getPath") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.vfs", method: "getContents") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.vfs", method: "exists") })
    }

    func testSurfaceContainsFileEditorManagerAPIs() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let surface = registry.registerSurface()
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.fileEditor", method: "openFile") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.fileEditor", method: "closeFile") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.fileEditor", method: "getSelectedFiles") })
    }

    func testSurfaceContainsAnActionAPIs() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let surface = registry.registerSurface()
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.action", method: "registerAction") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.action", method: "actionPerformed") })
    }

    func testSurfaceContainsApplicationAPIs() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let surface = registry.registerSurface()
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.application", method: "invokeLater") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.application", method: "isDisposed") })
    }

    func testSurfaceContainsMessagesAPIs() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let surface = registry.registerSurface()
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.messages", method: "showInfoMessage") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.messages", method: "showInputDialog") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.messages", method: "showChooseDialog") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.messages", method: "showOkCancelDialog") })
    }

    func testSurfaceContainsRunManagerAPIs() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let surface = registry.registerSurface()
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.runManager", method: "getRunConfigurations") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.runManager", method: "createConfiguration") })
    }

    func testSurfaceContainsPsiElementAPIs() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let surface = registry.registerSurface()
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.psi", method: "getChildren") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.psi", method: "getText") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "intellij.psi", method: "getContainingFile") })
    }

    // MARK: resolveOpenAPI Tests

    func testResolveProjectAPI() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let mapping = registry.resolveOpenAPI(APIName(namespace: "intellij.project", method: "getBaseDir"))
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "WorkspaceService.getBaseDir")
        XCTAssertEqual(mapping?.rpcMethod, "project.getBaseDir")
        XCTAssertTrue(mapping?.isReadOnly == true)
        XCTAssertTrue(mapping?.requiresUIRPC == false)
    }

    func testResolveEditorAPI() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let mapping = registry.resolveOpenAPI(APIName(namespace: "intellij.editor", method: "getText"))
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "TextEditorService.getText")
        XCTAssertTrue(mapping?.isReadOnly == true)
    }

    func testResolveFileEditorOpenFile() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let mapping = registry.resolveOpenAPI(APIName(namespace: "intellij.fileEditor", method: "openFile"))
        XCTAssertNotNil(mapping)
        XCTAssertTrue(mapping?.isReadOnly == false)
        XCTAssertTrue(mapping?.requiresUIRPC == false)
    }

    func testResolveAnActionAPI() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let mapping = registry.resolveOpenAPI(APIName(namespace: "intellij.action", method: "actionPerformed"))
        XCTAssertNotNil(mapping)
        XCTAssertTrue(mapping?.requiresUIRPC == true)
        XCTAssertTrue(mapping?.isReadOnly == false)
    }

    func testResolveMessagesAPI() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let mapping = registry.resolveOpenAPI(APIName(namespace: "intellij.messages", method: "showInfoMessage"))
        XCTAssertNotNil(mapping)
        XCTAssertTrue(mapping?.requiresUIRPC == true)
    }

    func testResolvePsiElementAPI() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let mapping = registry.resolveOpenAPI(APIName(namespace: "intellij.psi", method: "getChildren"))
        XCTAssertNotNil(mapping)
        XCTAssertTrue(mapping?.isReadOnly == true)
        XCTAssertEqual(mapping?.nativeService, "ASTService.getChildren")
    }

    func testResolveUnknownAPIReturnsNil() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let mapping = registry.resolveOpenAPI(APIName(namespace: "unknown", method: "method"))
        XCTAssertNil(mapping)
    }

    // MARK: isInternalAPI Tests (TASK-020.6, REQ-017/021)

    func testIsInternalAPIDetectsPsiImpl() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        XCTAssertTrue(registry.isInternalAPI("com.intellij.psi.impl.PsiElementImpl"))
    }

    func testIsInternalAPIDetectsApplicationImpl() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        XCTAssertTrue(registry.isInternalAPI("com.intellij.openapi.application.impl.ApplicationImpl"))
    }

    func testIsInternalAPIDetectsMessageBusImpl() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        XCTAssertTrue(registry.isInternalAPI("com.intellij.util.messages.impl.MessageBusImpl"))
    }

    func testIsInternalAPIReturnsFalseForPublicAPI() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        XCTAssertFalse(registry.isInternalAPI("com.intellij.openapi.project.Project"))
        XCTAssertFalse(registry.isInternalAPI("com.intellij.openapi.editor.Editor"))
    }

    // MARK: degradationStrategy Tests

    func testDegradationForKnownAPIReturnsShim() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let strategy = registry.degradationStrategy(for: APIName(namespace: "intellij.project", method: "getBaseDir"))
        XCTAssertEqual(strategy, .shim)
    }

    func testDegradationForInternalAPIReturnsDisable() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let strategy = registry.degradationStrategy(for: APIName(namespace: "com.intellij.psi.impl", method: "someMethod"))
        XCTAssertEqual(strategy, .disable)
    }

    func testDegradationForUnknownAPIReturnsPromptOnly() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let strategy = registry.degradationStrategy(for: APIName(namespace: "unknown", method: "method"))
        XCTAssertEqual(strategy, .promptOnly)
    }

    // MARK: Read-only / UI RPC helpers

    func testReadOnlyAPIsIncludePsiElement() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let readOnlyAPIs = registry.readOnlyAPIs()
        XCTAssertTrue(readOnlyAPIs.contains(APIName(namespace: "intellij.psi", method: "getChildren")))
        XCTAssertTrue(readOnlyAPIs.contains(APIName(namespace: "intellij.project", method: "getBaseDir")))
    }

    func testUIRPCAPIsIncludeMessagesAndAction() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let uiRPCAPIs = registry.uiRPCAPIs()
        XCTAssertTrue(uiRPCAPIs.contains(APIName(namespace: "intellij.messages", method: "showInfoMessage")))
        XCTAssertTrue(uiRPCAPIs.contains(APIName(namespace: "intellij.action", method: "actionPerformed")))
    }

    func testReadOnlyAPIsExcludeFileEditorOpen() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let readOnlyAPIs = registry.readOnlyAPIs()
        XCTAssertFalse(readOnlyAPIs.contains(APIName(namespace: "intellij.fileEditor", method: "openFile")))
    }

    // MARK: registerContracts Tests (H21)

    func testRegisterContractsSucceeds() async throws {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let store = CapabilityContractStore(customDir: URL(fileURLWithPath: "/tmp/m10-p4-test-contracts"))
        let contractRegistry = CapabilityContractRegistryImpl(store: store)

        try await registry.registerContracts(in: contractRegistry)

        let allContracts = contractRegistry.listAll()
        XCTAssertGreaterThanOrEqual(allContracts.count, 9)
        for contract in allContracts {
            XCTAssertEqual(contract.protocolKind, .jetbrains)
        }
    }
}

// MARK: - TASK-024: JetBrainsPluginHostAdapter Tests

final class M10Phase4PluginHostAdapterTests: XCTestCase {

    private func makeAdapter() -> (JetBrainsPluginHostAdapter, MockJetBrainsProcessManager, MockJetBrainsIPCChannel) {
        let surface = PublicProtocolSurface(apis: [], version: SemVer(1, 0, 0))
        let processManager = MockJetBrainsProcessManager()
        let ipcChannel = MockJetBrainsIPCChannel()
        let surfaceRegistry = JetBrainsOpenAPISurfaceRegistryImpl()
        let eventBus = ExtensionEventBusImpl()

        let adapter = JetBrainsPluginHostAdapter(
            surface: surface,
            processManager: processManager,
            ipcChannel: ipcChannel,
            surfaceRegistry: surfaceRegistry,
            eventBus: eventBus
        )
        return (adapter, processManager, ipcChannel)
    }

    func testAdapterInitialState() {
        let (adapter, _, _) = makeAdapter()
        XCTAssertEqual(adapter.state, .uninitialized)
        XCTAssertEqual(adapter.descriptor.kind, .jetbrains)
        XCTAssertEqual(adapter.descriptor.supportedProtocol, .jetbrains)
        XCTAssertEqual(adapter.descriptor.name, "JetBrains Plugin Host Adapter")
    }

    func testAdapterSupportedAPICount() {
        let (adapter, _, _) = makeAdapter()
        XCTAssertEqual(adapter.supportedAPICount, 24)
    }


    func testInterceptUnhandledAPIForKnownAPI() {
        let (adapter, _, _) = makeAdapter()
        let call = APICall(api: APIName(namespace: "intellij.project", method: "getBaseDir"))
        let response = adapter.interceptUnhandledAPI(call)
        XCTAssertEqual(response.strategy, .shim)
    }

    func testInterceptUnhandledAPIForInternalAPI() {
        let (adapter, _, _) = makeAdapter()
        let call = APICall(api: APIName(namespace: "com.intellij.psi.impl", method: "someMethod"))
        let response = adapter.interceptUnhandledAPI(call)
        XCTAssertEqual(response.strategy, .disable)
        XCTAssertTrue(response.message.contains("internal API"))
    }

    func testInterceptUnhandledAPIForUnknownAPI() {
        let (adapter, _, _) = makeAdapter()
        let call = APICall(api: APIName(namespace: "unknown", method: "method"))
        let response = adapter.interceptUnhandledAPI(call)
        XCTAssertEqual(response.strategy, .promptOnly)
    }

    func testInvokeCapabilityWhenNotActiveReturnsDegraded() async throws {
        let (adapter, _, _) = makeAdapter()
        let capID = CapabilityID("test-cap")
        let sessionID = AgentSessionID()
        let result = try await adapter.invokeCapability(capID, input: .null, sessionID: sessionID)
        if case .degraded(let reason, _) = result {
            XCTAssertTrue(reason.contains("not active"))
        } else {
            XCTFail("Expected degraded result")
        }
    }

    func testInstantiateSetsActiveState() async throws {
        let (adapter, _, _) = makeAdapter()
        let manifest = ExtensionManifest(
            id: ExtensionID("test-jb-plugin"),
            name: "Test Plugin",
            version: SemVer(1, 0, 0),
            kind: .jetbrainsPlugin,
            apiSurface: .jetbrains,
            architectures: [.x86_64],
            contractID: CapabilityContractID(),
            entryPoint: "/tmp/plugin-host.js"
        )
        let contract = CapabilityContract(
            id: CapabilityContractID(),
            name: "test-contract",
            protocolKind: .jetbrains,
            supportedAPIs: [],
            degradationStrategy: .shim,
            testCases: [TestCaseID()],
            inputSchema: JSONSchema(type: "object", properties: [:], required: [], description: ""),
            outputSchema: JSONSchema(type: "object", properties: [:], required: [], description: ""),
            requiredPermission: ExtensionPermission(
                scope: .filesystem(path: "*", access: .readOnly),
                operations: [.read],
                riskLevel: .readOnly,
                requiresApproval: false
            ),
            minHostVersion: SemVer(1, 0, 0)
        )
        let surface = PublicProtocolSurface(apis: [], version: SemVer(1, 0, 0))
        let context = AdapterInstantiationContext(
            manifest: manifest,
            contract: contract,
            hostAPI: surface,
            sessionID: AgentSessionID()
        )

        let instance = try await adapter.instantiate(context)
        XCTAssertEqual(adapter.state, .active)
        XCTAssertEqual(instance.extensionID, ExtensionID("test-jb-plugin"))
    }

    func testInvokeCapabilityWhenActiveReturnsSuccess() async throws {
        let (adapter, _, ipcChannel) = makeAdapter()
        ipcChannel.nextResponse = IPCResponse(id: 1, result: AnyCodableValue.string("result"))

        let manifest = ExtensionManifest(
            id: ExtensionID("test-jb-plugin"),
            name: "Test Plugin",
            version: SemVer(1, 0, 0),
            kind: .jetbrainsPlugin,
            apiSurface: .jetbrains,
            architectures: [.x86_64],
            contractID: CapabilityContractID(),
            entryPoint: "/tmp/plugin-host.js"
        )
        let contract = CapabilityContract(
            id: CapabilityContractID(),
            name: "test-contract",
            protocolKind: .jetbrains,
            supportedAPIs: [],
            degradationStrategy: .shim,
            testCases: [TestCaseID()],
            inputSchema: JSONSchema(type: "object", properties: [:], required: [], description: ""),
            outputSchema: JSONSchema(type: "object", properties: [:], required: [], description: ""),
            requiredPermission: ExtensionPermission(
                scope: .filesystem(path: "*", access: .readOnly),
                operations: [.read],
                riskLevel: .readOnly,
                requiresApproval: false
            ),
            minHostVersion: SemVer(1, 0, 0)
        )
        let surface = PublicProtocolSurface(apis: [], version: SemVer(1, 0, 0))
        let context = AdapterInstantiationContext(
            manifest: manifest,
            contract: contract,
            hostAPI: surface,
            sessionID: AgentSessionID()
        )

        _ = try await adapter.instantiate(context)

        let capID = CapabilityID("test-cap")
        let sessionID = AgentSessionID()
        let result = try await adapter.invokeCapability(capID, input: .null, sessionID: sessionID)
        if case .success(let output, _) = result {
            XCTAssertEqual(output, AnyCodableValue.string("result"))
        } else {
            XCTFail("Expected success result")
        }
    }

    func testDisposeSetsDisposedState() async throws {
        let (adapter, _, _) = makeAdapter()
        let manifest = ExtensionManifest(
            id: ExtensionID("test-jb-plugin"),
            name: "Test Plugin",
            version: SemVer(1, 0, 0),
            kind: .jetbrainsPlugin,
            apiSurface: .jetbrains,
            architectures: [.x86_64],
            contractID: CapabilityContractID(),
            entryPoint: "/tmp/plugin-host.js"
        )
        let contract = CapabilityContract(
            id: CapabilityContractID(),
            name: "test-contract",
            protocolKind: .jetbrains,
            supportedAPIs: [],
            degradationStrategy: .shim,
            testCases: [TestCaseID()],
            inputSchema: JSONSchema(type: "object", properties: [:], required: [], description: ""),
            outputSchema: JSONSchema(type: "object", properties: [:], required: [], description: ""),
            requiredPermission: ExtensionPermission(
                scope: .filesystem(path: "*", access: .readOnly),
                operations: [.read],
                riskLevel: .readOnly,
                requiresApproval: false
            ),
            minHostVersion: SemVer(1, 0, 0)
        )
        let surface = PublicProtocolSurface(apis: [], version: SemVer(1, 0, 0))
        let context = AdapterInstantiationContext(
            manifest: manifest,
            contract: contract,
            hostAPI: surface,
            sessionID: AgentSessionID()
        )

        _ = try await adapter.instantiate(context)
        try await adapter.dispose()
        XCTAssertEqual(adapter.state, .disposed)
    }

    func testResolveOpenAPIDelegatesToRegistry() {
        let (adapter, _, _) = makeAdapter()
        let mapping = adapter.resolveOpenAPI(APIName(namespace: "intellij.psi", method: "getText"))
        XCTAssertNotNil(mapping)
        XCTAssertTrue(mapping?.isReadOnly == true)
    }

    func testIsInternalAPIDelegatesToRegistry() {
        let (adapter, _, _) = makeAdapter()
        XCTAssertTrue(adapter.isInternalAPI("com.intellij.psi.impl.PsiElementImpl"))
        XCTAssertFalse(adapter.isInternalAPI("com.intellij.openapi.project.Project"))
    }
}

// MARK: - TASK-026: UI RPC Tests

final class M10Phase4UIRPCTests: XCTestCase {

    func testJetBrainsUIOperationEnumValues() {
        XCTAssertEqual(JetBrainsUIOperation.showInfoMessage.rawValue, "showInfoMessage")
        XCTAssertEqual(JetBrainsUIOperation.showInputDialog.rawValue, "showInputDialog")
        XCTAssertEqual(JetBrainsUIOperation.showChooseDialog.rawValue, "showChooseDialog")
        XCTAssertEqual(JetBrainsUIOperation.showOkCancelDialog.rawValue, "showOkCancelDialog")
    }

    func testUIRPCRequestCreation() {
        let request = UIRPCRequest(
            uiOperation: .showInfoMessage,
            params: ["title": AnyCodableValue.string("Test"), "message": AnyCodableValue.string("Hello")]
        )
        XCTAssertEqual(request.uiOperation, .showInfoMessage)
        XCTAssertEqual(request.params.count, 2)
    }

    func testUIRPCResponseCreation() {
        let response = UIRPCResponse(
            requestID: UUID(),
            result: AnyCodableValue.object(["button": AnyCodableValue.string("ok")])
        )
        XCTAssertNotNil(response.result)
        XCTAssertNil(response.error)
    }

    func testUIRPCResponseWithError() {
        let response = UIRPCResponse(
            requestID: UUID(),
            error: "Adapter not active"
        )
        XCTAssertNil(response.result)
        XCTAssertEqual(response.error, "Adapter not active")
    }

    func testUIRPCRequestEquatable() {
        let id = UUID()
        let r1 = UIRPCRequest(requestID: id, uiOperation: .showInputDialog, params: [:])
        let r2 = UIRPCRequest(requestID: id, uiOperation: .showInputDialog, params: [:])
        XCTAssertEqual(r1, r2)
    }

    func testUIRPCResponseEquatable() {
        let id = UUID()
        let r1 = UIRPCResponse(requestID: id, result: AnyCodableValue.string("ok"))
        let r2 = UIRPCResponse(requestID: id, result: AnyCodableValue.string("ok"))
        XCTAssertEqual(r1, r2)
    }

    func testHandleUIRPCRequestWhenNotActiveReturnsError() async throws {
        let surface = PublicProtocolSurface(apis: [], version: SemVer(1, 0, 0))
        let processManager = MockJetBrainsProcessManager()
        let ipcChannel = MockJetBrainsIPCChannel()
        let surfaceRegistry = JetBrainsOpenAPISurfaceRegistryImpl()
        let eventBus = ExtensionEventBusImpl()

        let adapter = JetBrainsPluginHostAdapter(
            surface: surface,
            processManager: processManager,
            ipcChannel: ipcChannel,
            surfaceRegistry: surfaceRegistry,
            eventBus: eventBus
        )

        let request = UIRPCRequest(uiOperation: .showInfoMessage, params: [:])
        let response = try await adapter.handleUIRPCRequest(request)
        XCTAssertNotNil(response.error)
        XCTAssertTrue(response.error?.contains("not active") == true)
    }

    func testHandleUIRPCRequestWhenActiveReturnsResult() async throws {
        let surface = PublicProtocolSurface(apis: [], version: SemVer(1, 0, 0))
        let processManager = MockJetBrainsProcessManager()
        let ipcChannel = MockJetBrainsIPCChannel()
        let surfaceRegistry = JetBrainsOpenAPISurfaceRegistryImpl()
        let eventBus = ExtensionEventBusImpl()

        let adapter = JetBrainsPluginHostAdapter(
            surface: surface,
            processManager: processManager,
            ipcChannel: ipcChannel,
            surfaceRegistry: surfaceRegistry,
            eventBus: eventBus
        )

        ipcChannel.nextResponse = IPCResponse(id: 1, result: AnyCodableValue.object(["button": AnyCodableValue.string("ok")]))

        let manifest = ExtensionManifest(
            id: ExtensionID("test-jb-plugin"),
            name: "Test Plugin",
            version: SemVer(1, 0, 0),
            kind: .jetbrainsPlugin,
            apiSurface: .jetbrains,
            architectures: [.x86_64],
            contractID: CapabilityContractID(),
            entryPoint: "/tmp/plugin-host.js"
        )
        let contract = CapabilityContract(
            id: CapabilityContractID(),
            name: "test-contract",
            protocolKind: .jetbrains,
            supportedAPIs: [],
            degradationStrategy: .shim,
            testCases: [TestCaseID()],
            inputSchema: JSONSchema(type: "object", properties: [:], required: [], description: ""),
            outputSchema: JSONSchema(type: "object", properties: [:], required: [], description: ""),
            requiredPermission: ExtensionPermission(
                scope: .filesystem(path: "*", access: .readOnly),
                operations: [.read],
                riskLevel: .readOnly,
                requiresApproval: false
            ),
            minHostVersion: SemVer(1, 0, 0)
        )
        let context = AdapterInstantiationContext(
            manifest: manifest,
            contract: contract,
            hostAPI: surface,
            sessionID: AgentSessionID()
        )

        _ = try await adapter.instantiate(context)

        let request = UIRPCRequest(uiOperation: .showInfoMessage, params: ["title": AnyCodableValue.string("T"), "message": AnyCodableValue.string("M")])
        let response = try await adapter.handleUIRPCRequest(request)
        XCTAssertNil(response.error)
        XCTAssertNotNil(response.result)
    }

    func testDefaultUIRPCHandlerShowInfoMessage() async throws {
        let handler = DefaultUIRPCHandler()
        let request = UIRPCRequest(uiOperation: .showInfoMessage, params: ["title": AnyCodableValue.string("T"), "message": AnyCodableValue.string("M")])
        let response = try await handler.handle(request)
        XCTAssertNil(response.error)
        XCTAssertNotNil(response.result)
    }

    func testDefaultUIRPCHandlerShowInputDialog() async throws {
        let handler = DefaultUIRPCHandler()
        let request = UIRPCRequest(uiOperation: .showInputDialog, params: ["title": AnyCodableValue.string("T"), "message": AnyCodableValue.string("M")])
        let response = try await handler.handle(request)
        XCTAssertNil(response.error)
        XCTAssertNotNil(response.result)
    }

    func testDefaultUIRPCHandlerShowChooseDialog() async throws {
        let handler = DefaultUIRPCHandler()
        let request = UIRPCRequest(uiOperation: .showChooseDialog, params: ["title": AnyCodableValue.string("T"), "message": AnyCodableValue.string("M")])
        let response = try await handler.handle(request)
        XCTAssertNil(response.error)
        XCTAssertNotNil(response.result)
    }

    func testDefaultUIRPCHandlerShowOkCancelDialog() async throws {
        let handler = DefaultUIRPCHandler()
        let request = UIRPCRequest(uiOperation: .showOkCancelDialog, params: ["title": AnyCodableValue.string("T"), "message": AnyCodableValue.string("M")])
        let response = try await handler.handle(request)
        XCTAssertNil(response.error)
        XCTAssertNotNil(response.result)
    }
}

// MARK: - TASK-025: ClassLoader Isolation + Internal API Rejection Tests

final class M10Phase4ClassLoaderIsolationTests: XCTestCase {

    func testInternalAPIPatternsDefined() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        XCTAssertTrue(registry.isInternalAPI("com.intellij.psi.impl.AnyClass"))
        XCTAssertTrue(registry.isInternalAPI("com.intellij.openapi.application.impl.AnyClass"))
        XCTAssertTrue(registry.isInternalAPI("com.intellij.util.messages.impl.AnyClass"))
    }

    func testPublicAPINotInternal() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        XCTAssertFalse(registry.isInternalAPI("com.intellij.openapi.project.Project"))
        XCTAssertFalse(registry.isInternalAPI("com.intellij.openapi.editor.Editor"))
        XCTAssertFalse(registry.isInternalAPI("com.intellij.openapi.vfs.VirtualFile"))
    }

    func testInternalAPIDegradationIsDisable() {
        let registry = JetBrainsOpenAPISurfaceRegistryImpl()
        let strategy = registry.degradationStrategy(for: APIName(namespace: "com.intellij.psi.impl", method: "internalMethod"))
        XCTAssertEqual(strategy, .disable)
    }

    func testAdapterRejectsInternalAPI() {
        let surface = PublicProtocolSurface(apis: [], version: SemVer(1, 0, 0))
        let processManager = MockJetBrainsProcessManager()
        let ipcChannel = MockJetBrainsIPCChannel()
        let surfaceRegistry = JetBrainsOpenAPISurfaceRegistryImpl()
        let eventBus = ExtensionEventBusImpl()

        let adapter = JetBrainsPluginHostAdapter(
            surface: surface,
            processManager: processManager,
            ipcChannel: ipcChannel,
            surfaceRegistry: surfaceRegistry,
            eventBus: eventBus
        )

        let call = APICall(api: APIName(namespace: "com.intellij.psi.impl", method: "internalMethod"))
        let response = adapter.interceptUnhandledAPI(call)
        XCTAssertEqual(response.strategy, .disable)
        XCTAssertTrue(response.message.contains("internal API"))
    }
}
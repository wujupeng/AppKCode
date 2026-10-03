import XCTest
@testable import AppKCodeDomain
import AppKCodeShared
import AppKCodeExtensionHost

// MARK: - Mock Process Manager

final class MockProcessManager: ExtensionHostProcessManager, @unchecked Sendable {
    let hostType: ExtensionHostType = .vscodeExtensionHost
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
        _state = .running(pid: ProcessID(12345))
        lock.unlock()
        return HostProcessHandle(processID: ProcessID(12345), ipcChannel: config.ipcChannel)
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

// MARK: - Mock IPC Channel

final class MockIPCChannel: IPCChannel, @unchecked Sendable {
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

// MARK: - VSCodeAPISurfaceRegistry Tests (TASK-011)

final class M10Phase2VSCodeAPISurfaceRegistryTests: XCTestCase {

    func testRegisterSurfaceReturns36APIs() {
        let registry = VSCodeAPISurfaceRegistryImpl()
        let surface = registry.registerSurface()
        XCTAssertEqual(surface.apis.count, 36)
        XCTAssertEqual(registry.apiCount, 36)
    }

    func testRegisterSurfaceContainsAllFSAPIs() {
        let registry = VSCodeAPISurfaceRegistryImpl()
        let surface = registry.registerSurface()
        let fsMethods = ["readFile", "writeFile", "readdir", "delete", "rename", "copy", "stat", "createDirectory"]
        for method in fsMethods {
            let apiName = APIName(namespace: "workspace.fs", method: method)
            XCTAssertTrue(surface.apis.contains { $0.name == apiName }, "Missing workspace.fs.\(method)")
        }
    }

    func testRegisterSurfaceContainsAllWorkspaceAPIs() {
        let registry = VSCodeAPISurfaceRegistryImpl()
        let surface = registry.registerSurface()
        let wsMethods = ["workspaceFolders", "getConfiguration", "onDidChangeConfiguration", "findFiles", "openTextDocument", "saveAll"]
        for method in wsMethods {
            let apiName = APIName(namespace: "workspace", method: method)
            XCTAssertTrue(surface.apis.contains { $0.name == apiName }, "Missing workspace.\(method)")
        }
    }

    func testRegisterSurfaceContainsAllWindowAPIs() {
        let registry = VSCodeAPISurfaceRegistryImpl()
        let surface = registry.registerSurface()
        let winMethods = ["showInformationMessage", "showErrorMessage", "showWarningMessage", "showInputBox", "showQuickPick", "createOutputChannel", "createTerminal", "activeTextEditor", "showTextDocument"]
        for method in winMethods {
            let apiName = APIName(namespace: "window", method: method)
            XCTAssertTrue(surface.apis.contains { $0.name == apiName }, "Missing window.\(method)")
        }
    }

    func testRegisterSurfaceContainsAllCommandsAPIs() {
        let registry = VSCodeAPISurfaceRegistryImpl()
        let surface = registry.registerSurface()
        let cmdMethods = ["executeCommand", "registerCommand"]
        for method in cmdMethods {
            let apiName = APIName(namespace: "commands", method: method)
            XCTAssertTrue(surface.apis.contains { $0.name == apiName }, "Missing commands.\(method)")
        }
    }

    func testRegisterSurfaceContainsAllLanguagesAPIs() {
        let registry = VSCodeAPISurfaceRegistryImpl()
        let surface = registry.registerSurface()
        let langMethods = ["registerCompletionItemProvider", "registerHoverProvider", "registerDefinitionProvider", "registerCodeActionsProvider", "createDiagnosticCollection"]
        for method in langMethods {
            let apiName = APIName(namespace: "languages", method: method)
            XCTAssertTrue(surface.apis.contains { $0.name == apiName }, "Missing languages.\(method)")
        }
    }

    func testRegisterSurfaceContainsExtensionsEnvTasksAPIs() {
        let registry = VSCodeAPISurfaceRegistryImpl()
        let surface = registry.registerSurface()

        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "extensions", method: "getExtension") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "extensions", method: "onDidChangeExtensions") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "env", method: "openExternal") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "env", method: "clipboard") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "tasks", method: "executeTask") })
        XCTAssertTrue(surface.apis.contains { $0.name == APIName(namespace: "tasks", method: "registerTaskProvider") })
    }

    // MARK: resolveAPI Tests

    func testResolveAPIForFSWriteFile() {
        let registry = VSCodeAPISurfaceRegistryImpl()
        let mapping = registry.resolveAPI(APIName(namespace: "workspace.fs", method: "writeFile"))
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "FileSystemService.write")
        XCTAssertTrue(mapping?.requiresAuthorization == true)
        XCTAssertEqual(mapping?.riskLevel, .high)
        XCTAssertEqual(mapping?.ipcMethod, "fs.writeFile")
    }

    func testResolveAPIForFSReadFile() {
        let registry = VSCodeAPISurfaceRegistryImpl()
        let mapping = registry.resolveAPI(APIName(namespace: "workspace.fs", method: "readFile"))
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "FileSystemService.read")
        XCTAssertTrue(mapping?.requiresAuthorization == false)
        XCTAssertEqual(mapping?.riskLevel, .readOnly)
    }

    func testResolveAPIForCreateTerminal() {
        let registry = VSCodeAPISurfaceRegistryImpl()
        let mapping = registry.resolveAPI(APIName(namespace: "window", method: "createTerminal"))
        XCTAssertNotNil(mapping)
        XCTAssertTrue(mapping?.requiresAuthorization == true)
        XCTAssertEqual(mapping?.riskLevel, .high)
    }

    func testResolveAPIForUnknownReturnsNil() {
        let registry = VSCodeAPISurfaceRegistryImpl()
        let mapping = registry.resolveAPI(APIName(namespace: "unknown", method: "method"))
        XCTAssertNil(mapping)
    }

    // MARK: degradationStrategy Tests

    func testDegradationStrategyForKnownAPIReturnsShim() {
        let registry = VSCodeAPISurfaceRegistryImpl()
        let strategy = registry.degradationStrategy(for: APIName(namespace: "workspace.fs", method: "readFile"))
        XCTAssertEqual(strategy, .shim)
    }

    func testDegradationStrategyForProposedAPIReturnsDisable() {
        let registry = VSCodeAPISurfaceRegistryImpl()
        let strategy = registry.degradationStrategy(for: APIName(namespace: "vscode.proposed", method: "someApi"))
        XCTAssertEqual(strategy, .disable)
    }

    func testDegradationStrategyForDebugStartDebuggingReturnsPromptOnly() {
        let registry = VSCodeAPISurfaceRegistryImpl()
        let strategy = registry.degradationStrategy(for: APIName(namespace: "debug", method: "startDebugging"))
        XCTAssertEqual(strategy, .promptOnly)
    }

    func testDegradationStrategyForUnknownAPIReturnsPromptOnly() {
        let registry = VSCodeAPISurfaceRegistryImpl()
        let strategy = registry.degradationStrategy(for: APIName(namespace: "unknown", method: "method"))
        XCTAssertEqual(strategy, .promptOnly)
    }

    // MARK: allSupportedAPIs Tests

    func testAllSupportedAPIsContains36Entries() {
        let registry = VSCodeAPISurfaceRegistryImpl()
        XCTAssertEqual(registry.allSupportedAPIs.count, 36)
    }
}

// MARK: - VSCodeExtensionHostAdapter Tests (TASK-014)

final class M10Phase2VSCodeExtensionHostAdapterTests: XCTestCase {

    func testAdapterInitialState() {
        let surface = PublicProtocolSurface(apis: [], version: SemVer(1, 0, 0))
        let processManager = MockProcessManager()
        let ipcChannel = MockIPCChannel()
        let surfaceRegistry = VSCodeAPISurfaceRegistryImpl()

        let adapter = VSCodeExtensionHostAdapter(
            surface: surface,
            processManager: processManager,
            ipcChannel: ipcChannel,
            surfaceRegistry: surfaceRegistry
        )

        XCTAssertEqual(adapter.state, .uninitialized)
        XCTAssertEqual(adapter.descriptor.kind, .vscode)
        XCTAssertEqual(adapter.descriptor.supportedProtocol, .vscode)
    }

    func testAdapterSupportedAPICount() {
        let surface = PublicProtocolSurface(apis: [], version: SemVer(1, 0, 0))
        let processManager = MockProcessManager()
        let ipcChannel = MockIPCChannel()
        let surfaceRegistry = VSCodeAPISurfaceRegistryImpl()

        let adapter = VSCodeExtensionHostAdapter(
            surface: surface,
            processManager: processManager,
            ipcChannel: ipcChannel,
            surfaceRegistry: surfaceRegistry
        )

        XCTAssertEqual(adapter.supportedAPICount, 36)
    }

    func testInterceptUnhandledAPIForKnownAPI() {
        let surface = PublicProtocolSurface(apis: [], version: SemVer(1, 0, 0))
        let processManager = MockProcessManager()
        let ipcChannel = MockIPCChannel()
        let surfaceRegistry = VSCodeAPISurfaceRegistryImpl()

        let adapter = VSCodeExtensionHostAdapter(
            surface: surface,
            processManager: processManager,
            ipcChannel: ipcChannel,
            surfaceRegistry: surfaceRegistry
        )

        let call = APICall(api: APIName(namespace: "workspace.fs", method: "readFile"))
        let response = adapter.interceptUnhandledAPI(call)
        XCTAssertEqual(response.strategy, .shim)
    }

    func testInterceptUnhandledAPIForProposedAPI() {
        let surface = PublicProtocolSurface(apis: [], version: SemVer(1, 0, 0))
        let processManager = MockProcessManager()
        let ipcChannel = MockIPCChannel()
        let surfaceRegistry = VSCodeAPISurfaceRegistryImpl()

        let adapter = VSCodeExtensionHostAdapter(
            surface: surface,
            processManager: processManager,
            ipcChannel: ipcChannel,
            surfaceRegistry: surfaceRegistry
        )

        let call = APICall(api: APIName(namespace: "vscode.proposed", method: "someApi"))
        let response = adapter.interceptUnhandledAPI(call)
        XCTAssertEqual(response.strategy, .disable)
    }

    func testInterceptUnhandledAPIForUnknownAPI() {
        let surface = PublicProtocolSurface(apis: [], version: SemVer(1, 0, 0))
        let processManager = MockProcessManager()
        let ipcChannel = MockIPCChannel()
        let surfaceRegistry = VSCodeAPISurfaceRegistryImpl()

        let adapter = VSCodeExtensionHostAdapter(
            surface: surface,
            processManager: processManager,
            ipcChannel: ipcChannel,
            surfaceRegistry: surfaceRegistry
        )

        let call = APICall(api: APIName(namespace: "unknown", method: "method"))
        let response = adapter.interceptUnhandledAPI(call)
        XCTAssertEqual(response.strategy, .promptOnly)
    }

    func testResolveAPIDelegatesToRegistry() {
        let surface = PublicProtocolSurface(apis: [], version: SemVer(1, 0, 0))
        let processManager = MockProcessManager()
        let ipcChannel = MockIPCChannel()
        let surfaceRegistry = VSCodeAPISurfaceRegistryImpl()

        let adapter = VSCodeExtensionHostAdapter(
            surface: surface,
            processManager: processManager,
            ipcChannel: ipcChannel,
            surfaceRegistry: surfaceRegistry
        )

        let mapping = adapter.resolveAPI(APIName(namespace: "workspace.fs", method: "writeFile"))
        XCTAssertNotNil(mapping)
        XCTAssertTrue(mapping?.requiresAuthorization == true)
    }
}
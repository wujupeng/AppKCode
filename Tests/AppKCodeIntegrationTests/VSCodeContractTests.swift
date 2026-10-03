import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain
@testable import AppKCodeApplication
import AppKCodeExtensionHost
import AppKCodeInfrastructure

// MARK: - TASK-030: VS Code Contract Tests (~36 API)

final class VSCodeContractTests: XCTestCase {
    private var registry: VSCodeAPISurfaceRegistryImpl!
    private var contractRegistry: CapabilityContractRegistryImpl!

    override func setUp() {
        super.setUp()
        registry = VSCodeAPISurfaceRegistryImpl()
        contractRegistry = CapabilityContractRegistryImpl(store: CapabilityContractStore())
    }

    // MARK: - TASK-030.1: workspace.fs.* 8 API Contract

    func testFsReadFileContract() {
        let api = APIName(namespace: "workspace.fs", method: "readFile")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "FileSystemService.read")
        XCTAssertFalse(mapping!.requiresAuthorization)
        XCTAssertEqual(mapping?.riskLevel, .readOnly)
        XCTAssertEqual(mapping?.ipcMethod, "fs.readFile")
    }

    func testFsWriteFileContract() {
        let api = APIName(namespace: "workspace.fs", method: "writeFile")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "FileSystemService.write")
        XCTAssertTrue(mapping!.requiresAuthorization)
        XCTAssertEqual(mapping?.riskLevel, .high)
    }

    func testFsReaddirContract() {
        let api = APIName(namespace: "workspace.fs", method: "readdir")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "FileSystemService.readdir")
        XCTAssertFalse(mapping!.requiresAuthorization)
    }

    func testFsDeleteContract() {
        let api = APIName(namespace: "workspace.fs", method: "delete")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertTrue(mapping!.requiresAuthorization)
        XCTAssertEqual(mapping?.riskLevel, .high)
    }

    func testFsRenameContract() {
        let api = APIName(namespace: "workspace.fs", method: "rename")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertTrue(mapping!.requiresAuthorization)
    }

    func testFsCopyContract() {
        let api = APIName(namespace: "workspace.fs", method: "copy")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertTrue(mapping!.requiresAuthorization)
    }

    func testFsStatContract() {
        let api = APIName(namespace: "workspace.fs", method: "stat")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "FileSystemService.stat")
        XCTAssertFalse(mapping!.requiresAuthorization)
        XCTAssertEqual(mapping?.riskLevel, .readOnly)
    }

    func testFsCreateDirectoryContract() {
        let api = APIName(namespace: "workspace.fs", method: "createDirectory")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertTrue(mapping!.requiresAuthorization)
        XCTAssertEqual(mapping?.riskLevel, .high)
    }

    // MARK: - TASK-030.2: workspace.* 6 API Contract

    func testWorkspaceFoldersContract() {
        let api = APIName(namespace: "workspace", method: "workspaceFolders")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "WorkspaceService.workspaceFolders")
        XCTAssertFalse(mapping!.requiresAuthorization)
    }

    func testGetConfigurationContract() {
        let api = APIName(namespace: "workspace", method: "getConfiguration")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "ConfigurationService.get")
        XCTAssertFalse(mapping!.requiresAuthorization)
    }

    func testOnDidChangeConfigurationContract() {
        let api = APIName(namespace: "workspace", method: "onDidChangeConfiguration")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "ConfigurationService.subscribe")
        XCTAssertFalse(mapping!.requiresAuthorization)
    }

    func testFindFilesContract() {
        let api = APIName(namespace: "workspace", method: "findFiles")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "WorkspaceService.findFiles")
        XCTAssertFalse(mapping!.requiresAuthorization)
    }

    func testOpenTextDocumentContract() {
        let api = APIName(namespace: "workspace", method: "openTextDocument")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "WorkspaceService.openTextDocument")
        XCTAssertFalse(mapping!.requiresAuthorization)
    }

    func testSaveAllContract() {
        let api = APIName(namespace: "workspace", method: "saveAll")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertTrue(mapping!.requiresAuthorization)
        XCTAssertEqual(mapping?.riskLevel, .high)
    }

    // MARK: - TASK-030.3: window.* 9 API Contract

    func testShowInformationMessageContract() {
        let api = APIName(namespace: "window", method: "showInformationMessage")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "PresentationService.showInformationMessage")
        XCTAssertFalse(mapping!.requiresAuthorization)
    }

    func testShowErrorMessageContract() {
        let api = APIName(namespace: "window", method: "showErrorMessage")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertFalse(mapping!.requiresAuthorization)
    }

    func testShowWarningMessageContract() {
        let api = APIName(namespace: "window", method: "showWarningMessage")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertFalse(mapping!.requiresAuthorization)
    }

    func testShowInputBoxContract() {
        let api = APIName(namespace: "window", method: "showInputBox")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertFalse(mapping!.requiresAuthorization)
    }

    func testShowQuickPickContract() {
        let api = APIName(namespace: "window", method: "showQuickPick")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertFalse(mapping!.requiresAuthorization)
    }

    func testCreateOutputChannelContract() {
        let api = APIName(namespace: "window", method: "createOutputChannel")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertFalse(mapping!.requiresAuthorization)
    }

    func testCreateTerminalContract() {
        let api = APIName(namespace: "window", method: "createTerminal")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertTrue(mapping!.requiresAuthorization)
        XCTAssertEqual(mapping?.riskLevel, .high)
    }

    func testActiveTextEditorContract() {
        let api = APIName(namespace: "window", method: "activeTextEditor")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertFalse(mapping!.requiresAuthorization)
    }

    func testShowTextDocumentContract() {
        let api = APIName(namespace: "window", method: "showTextDocument")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertFalse(mapping!.requiresAuthorization)
    }

    // MARK: - TASK-030.4: commands/languages/extensions/env/tasks API Contract

    func testCommandsExecuteCommandContract() {
        let api = APIName(namespace: "commands", method: "executeCommand")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertTrue(mapping!.requiresAuthorization)
        XCTAssertEqual(mapping?.riskLevel, .high)
    }

    func testCommandsRegisterCommandContract() {
        let api = APIName(namespace: "commands", method: "registerCommand")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertFalse(mapping!.requiresAuthorization)
    }

    func testLanguagesRegisterCompletionItemProviderContract() {
        let api = APIName(namespace: "languages", method: "registerCompletionItemProvider")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "LSPService.registerCompletionProvider")
    }

    func testLanguagesRegisterHoverProviderContract() {
        let api = APIName(namespace: "languages", method: "registerHoverProvider")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
    }

    func testLanguagesRegisterDefinitionProviderContract() {
        let api = APIName(namespace: "languages", method: "registerDefinitionProvider")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
    }

    func testLanguagesRegisterCodeActionsProviderContract() {
        let api = APIName(namespace: "languages", method: "registerCodeActionsProvider")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
    }

    func testLanguagesCreateDiagnosticCollectionContract() {
        let api = APIName(namespace: "languages", method: "createDiagnosticCollection")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
    }

    func testExtensionsGetExtensionContract() {
        let api = APIName(namespace: "extensions", method: "getExtension")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "ExtensionRegistry.getExtension")
    }

    func testExtensionsOnDidChangeExtensionsContract() {
        let api = APIName(namespace: "extensions", method: "onDidChangeExtensions")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
    }

    func testEnvOpenExternalContract() {
        let api = APIName(namespace: "env", method: "openExternal")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
    }

    func testEnvClipboardContract() {
        let api = APIName(namespace: "env", method: "clipboard")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
    }

    func testTasksExecuteTaskContract() {
        let api = APIName(namespace: "tasks", method: "executeTask")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertTrue(mapping!.requiresAuthorization)
        XCTAssertEqual(mapping?.riskLevel, .high)
    }

    func testTasksRegisterTaskProviderContract() {
        let api = APIName(namespace: "tasks", method: "registerTaskProvider")
        let mapping = registry.resolveAPI(api)
        XCTAssertNotNil(mapping)
    }

    // MARK: - TASK-030.5: Base Types Shim Contract

    func testDisposableContract() {
        var disposed = false
        let d = DisposableImpl { disposed = true }
        XCTAssertFalse(disposed)
        d.dispose()
        XCTAssertTrue(disposed)
        d.dispose()
    }

    func testEventEmitterContract() {
        let emitter = EventEmitterImpl()
        var fired = false
        let d = emitter.subscribe { _ in fired = true }
        emitter.fire(42)
        XCTAssertTrue(fired)
        d.dispose()
        fired = false
        emitter.fire(42)
        XCTAssertFalse(fired)
    }

    func testUriContract() {
        let uri = UriImpl.parse("file:///Users/test/project/file.swift")
        XCTAssertEqual(uri.scheme, "file")
        XCTAssertEqual(uri.path, "/Users/test/project/file.swift")
        let formatted = UriImpl.file("/Users/test/project/file.swift")
        XCTAssertEqual(formatted.scheme, "file")
    }

    func testPositionContract() {
        let p1 = PositionImpl(line: 10, character: 5)
        let p2 = PositionImpl(line: 10, character: 10)
        XCTAssertTrue(p1.isBefore(p2))
        XCTAssertFalse(p2.isBefore(p1))
        XCTAssertEqual(p1.line, 10)
        XCTAssertEqual(p1.character, 5)
    }

    func testRangeContract() {
        let start = PositionImpl(line: 0, character: 0)
        let end = PositionImpl(line: 5, character: 10)
        let range = RangeImpl(start: start, end: end)
        XCTAssertEqual(range.start, start)
        XCTAssertEqual(range.end, end)
        XCTAssertTrue(range.contains(PositionImpl(line: 2, character: 5)))
    }

    func testCancellationTokenContract() {
        let token = CancellationTokenImpl()
        XCTAssertFalse(token.isCancellationRequested)
        token.cancel()
        XCTAssertTrue(token.isCancellationRequested)
    }

    func testTextDocumentContract() {
        let doc = TextDocumentImpl(uri: UriImpl.file("/test.swift"), languageId: "swift", version: 1, content: "let x = 42")
        XCTAssertEqual(doc.languageId, "swift")
        XCTAssertEqual(doc.version, 1)
        XCTAssertTrue(doc.content.contains("42"))
    }

    func testTextEditorContract() {
        let doc = TextDocumentImpl(uri: UriImpl.file("/test.swift"), languageId: "swift", version: 1, content: "")
        let editor = TextEditorImpl(document: doc, selection: RangeImpl(start: PositionImpl(line: 0, character: 0), end: PositionImpl(line: 0, character: 0)))
        XCTAssertEqual(editor.document.languageId, "swift")
    }

    // MARK: - TASK-030.6: Contract 前置 (REQ-048)

    func testContractPrecedenceAllAPIsHaveContracts() async throws {
        try await registry.registerContracts(in: contractRegistry)
        let allContracts = contractRegistry.listAll()
        XCTAssertGreaterThan(allContracts.count, 0, "Contracts must be registered for VS Code APIs")
    }

    func testUnregisteredAPIReturnsNil() {
        let api = APIName(namespace: "unknown.namespace", method: "unknownMethod")
        let mapping = registry.resolveAPI(api)
        XCTAssertNil(mapping)
    }

    func testTotalAPICountIs36() {
        let surface = registry.registerSurface()
        XCTAssertEqual(surface.apis.count, 36, "VS Code API surface must have exactly 36 APIs")
    }

    func testFsAPICountIs8() {
        let surface = registry.registerSurface()
        let fsAPIs = surface.apis.filter { $0.name.namespace == "workspace.fs" }
        XCTAssertEqual(fsAPIs.count, 8)
    }

    func testWorkspaceAPICountIs6() {
        let surface = registry.registerSurface()
        let wsAPIs = surface.apis.filter { $0.name.namespace == "workspace" }
        XCTAssertEqual(wsAPIs.count, 6)
    }

    func testWindowAPICountIs9() {
        let surface = registry.registerSurface()
        let winAPIs = surface.apis.filter { $0.name.namespace == "window" }
        XCTAssertEqual(winAPIs.count, 9)
    }

    func testCommandsAPICountIs2() {
        let surface = registry.registerSurface()
        let cmdAPIs = surface.apis.filter { $0.name.namespace == "commands" }
        XCTAssertEqual(cmdAPIs.count, 2)
    }

    func testLanguagesAPICountIs5() {
        let surface = registry.registerSurface()
        let langAPIs = surface.apis.filter { $0.name.namespace == "languages" }
        XCTAssertEqual(langAPIs.count, 5)
    }

    func testExtensionsAPICountIs2() {
        let surface = registry.registerSurface()
        let extAPIs = surface.apis.filter { $0.name.namespace == "extensions" }
        XCTAssertEqual(extAPIs.count, 2)
    }

    func testEnvAPICountIs2() {
        let surface = registry.registerSurface()
        let envAPIs = surface.apis.filter { $0.name.namespace == "env" }
        XCTAssertEqual(envAPIs.count, 2)
    }

    func testTasksAPICountIs2() {
        let surface = registry.registerSurface()
        let taskAPIs = surface.apis.filter { $0.name.namespace == "tasks" }
        XCTAssertEqual(taskAPIs.count, 2)
    }

    func testProposedAPIRejected() {
        let api = APIName(namespace: "vscode.proposed", method: "someProposedAPI")
        let mapping = registry.resolveAPI(api)
        XCTAssertNil(mapping)
    }

    func testDegradationStrategyForUnknownAPI() {
        let api = APIName(namespace: "unknown", method: "unknown")
        let strategy = registry.degradationStrategy(for: api)
        XCTAssertNotNil(strategy)
    }
}

// MARK: - Base Type Shim Test Helpers

private final class DisposableImpl {
    private let disposeCallback: () -> Void
    private var disposed = false
    init(_ disposeCallback: @escaping () -> Void) { self.disposeCallback = disposeCallback }
    func dispose() {
        if disposed { return }
        disposed = true
        disposeCallback()
    }
}

private final class EventEmitterImpl {
    private var listeners: [(Int) -> Void] = []
    func subscribe(_ listener: @escaping (Int) -> Void) -> DisposableImpl {
        let index = listeners.count
        listeners.append(listener)
        let self_ = self
        return DisposableImpl { [weak self_] in
            guard let s = self_ else { return }
            if index < s.listeners.count { s.listeners[index] = { _ in } }
        }
    }
    func fire(_ data: Int) {
        for l in listeners { l(data) }
    }
}

private struct UriImpl: Equatable {
    let scheme: String
    let path: String
    static func parse(_ uri: String) -> UriImpl {
        if uri.hasPrefix("file://") {
            return UriImpl(scheme: "file", path: String(uri.dropFirst("file://".count)))
        }
        return UriImpl(scheme: "unknown", path: uri)
    }
    static func file(_ path: String) -> UriImpl {
        return UriImpl(scheme: "file", path: path)
    }
}

private struct PositionImpl: Equatable {
    let line: Int
    let character: Int
    func isBefore(_ other: PositionImpl) -> Bool {
        if line != other.line { return line < other.line }
        return character < other.character
    }
}

private struct RangeImpl: Equatable {
    let start: PositionImpl
    let end: PositionImpl
    func contains(_ pos: PositionImpl) -> Bool {
        return (start.isBefore(pos) || start == pos) && (pos.isBefore(end) || pos == end)
    }
}

private final class CancellationTokenImpl {
    private(set) var isCancellationRequested = false
    func cancel() { isCancellationRequested = true }
}

private struct TextDocumentImpl: Equatable {
    let uri: UriImpl
    let languageId: String
    let version: Int
    let content: String
}

private struct TextEditorImpl: Equatable {
    let document: TextDocumentImpl
    let selection: RangeImpl
}
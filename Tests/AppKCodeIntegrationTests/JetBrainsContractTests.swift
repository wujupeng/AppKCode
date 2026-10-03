import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain
@testable import AppKCodeApplication
import AppKCodeExtensionHost
import AppKCodeInfrastructure

// MARK: - TASK-031: JetBrains Contract Tests (~9 OpenAPI, 24 API methods)

final class JetBrainsContractTests: XCTestCase {
    private var registry: JetBrainsOpenAPISurfaceRegistryImpl!
    private var contractRegistry: CapabilityContractRegistryImpl!

    override func setUp() {
        super.setUp()
        registry = JetBrainsOpenAPISurfaceRegistryImpl()
        contractRegistry = CapabilityContractRegistryImpl(store: CapabilityContractStore())
    }

    // MARK: - TASK-031.1: Project/Editor/VirtualFile/FileEditorManager 4 OpenAPI Contract

    // Project OpenAPI (2 APIs)

    func testProjectGetBaseDirContract() {
        let api = APIName(namespace: "intellij.project", method: "getBaseDir")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "WorkspaceService.getBaseDir")
        XCTAssertTrue(mapping!.isReadOnly)
        XCTAssertFalse(mapping!.requiresUIRPC)
        XCTAssertEqual(mapping?.rpcMethod, "project.getBaseDir")
    }

    func testProjectGetProjectDirContract() {
        let api = APIName(namespace: "intellij.project", method: "getProjectDir")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "WorkspaceService.getProjectDir")
        XCTAssertTrue(mapping!.isReadOnly)
    }

    // Editor OpenAPI (3 APIs)

    func testEditorGetTextContract() {
        let api = APIName(namespace: "intellij.editor", method: "getText")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "TextEditorService.getText")
        XCTAssertTrue(mapping!.isReadOnly)
        XCTAssertFalse(mapping!.requiresUIRPC)
    }

    func testEditorGetCaretModelContract() {
        let api = APIName(namespace: "intellij.editor", method: "getCaretModel")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "TextEditorService.getCaretModel")
        XCTAssertTrue(mapping!.isReadOnly)
    }

    func testEditorGetSelectionModelContract() {
        let api = APIName(namespace: "intellij.editor", method: "getSelectionModel")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "TextEditorService.getSelectionModel")
        XCTAssertTrue(mapping!.isReadOnly)
    }

    // VirtualFile OpenAPI (3 APIs)

    func testVfsGetPathContract() {
        let api = APIName(namespace: "intellij.vfs", method: "getPath")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "FileSystemService.getPath")
        XCTAssertTrue(mapping!.isReadOnly)
        XCTAssertEqual(mapping?.rpcMethod, "vfs.getPath")
    }

    func testVfsGetContentsContract() {
        let api = APIName(namespace: "intellij.vfs", method: "getContents")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "FileSystemService.getContents")
        XCTAssertTrue(mapping!.isReadOnly)
    }

    func testVfsExistsContract() {
        let api = APIName(namespace: "intellij.vfs", method: "exists")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "FileSystemService.exists")
        XCTAssertTrue(mapping!.isReadOnly)
    }

    // FileEditorManager OpenAPI (3 APIs)

    func testFileEditorOpenFileContract() {
        let api = APIName(namespace: "intellij.fileEditor", method: "openFile")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "EditorManagerService.openFile")
        XCTAssertFalse(mapping!.isReadOnly)
        XCTAssertFalse(mapping!.requiresUIRPC)
    }

    func testFileEditorCloseFileContract() {
        let api = APIName(namespace: "intellij.fileEditor", method: "closeFile")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "EditorManagerService.closeFile")
        XCTAssertFalse(mapping!.isReadOnly)
    }

    func testFileEditorGetSelectedFilesContract() {
        let api = APIName(namespace: "intellij.fileEditor", method: "getSelectedFiles")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "EditorManagerService.getSelectedFiles")
        XCTAssertTrue(mapping!.isReadOnly)
    }

    // MARK: - TASK-031.2: AnAction/Application/Messages/RunManager 4 OpenAPI Contract (UI RPC)

    // AnAction OpenAPI (2 APIs, requiresUIRPC = true)

    func testActionRegisterActionContract() {
        let api = APIName(namespace: "intellij.action", method: "registerAction")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "ActionRegistry.register")
        XCTAssertTrue(mapping!.requiresUIRPC)
        XCTAssertEqual(mapping?.rpcMethod, "action.registerAction")
    }

    func testActionActionPerformedContract() {
        let api = APIName(namespace: "intellij.action", method: "actionPerformed")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "ActionRegistry.perform")
        XCTAssertTrue(mapping!.requiresUIRPC)
    }

    // Application OpenAPI (2 APIs)

    func testApplicationInvokeLaterContract() {
        let api = APIName(namespace: "intellij.application", method: "invokeLater")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "ApplicationService.invokeLater")
        XCTAssertFalse(mapping!.isReadOnly)
        XCTAssertFalse(mapping!.requiresUIRPC)
    }

    func testApplicationIsDisposedContract() {
        let api = APIName(namespace: "intellij.application", method: "isDisposed")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "ApplicationService.isDisposed")
        XCTAssertTrue(mapping!.isReadOnly)
    }

    // Messages OpenAPI (4 APIs, requiresUIRPC = true)

    func testMessagesShowInfoMessageContract() {
        let api = APIName(namespace: "intellij.messages", method: "showInfoMessage")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "UIService.showInfoMessage")
        XCTAssertTrue(mapping!.requiresUIRPC)
        XCTAssertEqual(mapping?.rpcMethod, "ui.showInfoMessage")
    }

    func testMessagesShowInputDialogContract() {
        let api = APIName(namespace: "intellij.messages", method: "showInputDialog")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "UIService.showInputDialog")
        XCTAssertTrue(mapping!.requiresUIRPC)
    }

    func testMessagesShowChooseDialogContract() {
        let api = APIName(namespace: "intellij.messages", method: "showChooseDialog")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "UIService.showChooseDialog")
        XCTAssertTrue(mapping!.requiresUIRPC)
    }

    func testMessagesShowOkCancelDialogContract() {
        let api = APIName(namespace: "intellij.messages", method: "showOkCancelDialog")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "UIService.showOkCancelDialog")
        XCTAssertTrue(mapping!.requiresUIRPC)
    }

    // RunManager OpenAPI (2 APIs)

    func testRunManagerGetRunConfigurationsContract() {
        let api = APIName(namespace: "intellij.runManager", method: "getRunConfigurations")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "BuildRunService.getRunConfigurations")
        XCTAssertTrue(mapping!.isReadOnly)
        XCTAssertFalse(mapping!.requiresUIRPC)
    }

    func testRunManagerCreateConfigurationContract() {
        let api = APIName(namespace: "intellij.runManager", method: "createConfiguration")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "BuildRunService.createConfiguration")
        XCTAssertFalse(mapping!.isReadOnly)
    }

    // MARK: - TASK-031.3: PsiElement 只读契约 (REQ-019)

    func testPsiGetChildrenContract() {
        let api = APIName(namespace: "intellij.psi", method: "getChildren")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "ASTService.getChildren")
        XCTAssertTrue(mapping!.isReadOnly)
        XCTAssertFalse(mapping!.requiresUIRPC)
    }

    func testPsiGetTextContract() {
        let api = APIName(namespace: "intellij.psi", method: "getText")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "ASTService.getText")
        XCTAssertTrue(mapping!.isReadOnly)
    }

    func testPsiGetContainingFileContract() {
        let api = APIName(namespace: "intellij.psi", method: "getContainingFile")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.nativeService, "ASTService.getContainingFile")
        XCTAssertTrue(mapping!.isReadOnly)
    }

    func testPsiElementReadOnlyNoWriteOperations() {
        let writeMethods = ["add", "replace", "delete"]
        for method in writeMethods {
            let api = APIName(namespace: "intellij.psi", method: method)
            let mapping = registry.resolveOpenAPI(api)
            XCTAssertNil(mapping, "PsiElement write method '\(method)' should not be in OpenAPI surface (REQ-019 read-only)")
        }
    }

    // MARK: - TASK-031.4: Contract 前置 (REQ-048)

    func testContractPrecedenceAllOpenAPIsHaveContracts() async throws {
        try await registry.registerContracts(in: contractRegistry)
        let allContracts = contractRegistry.listAll()
        XCTAssertGreaterThan(allContracts.count, 0, "Contracts must be registered for JetBrains OpenAPIs")
    }

    func testUnregisteredOpenAPIReturnsNil() {
        let api = APIName(namespace: "intellij.unknown", method: "unknownMethod")
        let mapping = registry.resolveOpenAPI(api)
        XCTAssertNil(mapping)
    }

    func testTotalOpenAPIMethodCountIs24() {
        let surface = registry.registerSurface()
        XCTAssertEqual(surface.apis.count, 24, "JetBrains OpenAPI surface must have exactly 24 API methods")
    }

    func testTotalOpenAPIInterfaceCountIs9() {
        let surface = registry.registerSurface()
        let namespaces = Set(surface.apis.map { $0.name.namespace })
        XCTAssertEqual(namespaces.count, 9, "JetBrains OpenAPI surface must have exactly 9 interfaces")
    }

    func testProjectAPICountIs2() {
        let surface = registry.registerSurface()
        let apis = surface.apis.filter { $0.name.namespace == "intellij.project" }
        XCTAssertEqual(apis.count, 2)
    }

    func testEditorAPICountIs3() {
        let surface = registry.registerSurface()
        let apis = surface.apis.filter { $0.name.namespace == "intellij.editor" }
        XCTAssertEqual(apis.count, 3)
    }

    func testVfsAPICountIs3() {
        let surface = registry.registerSurface()
        let apis = surface.apis.filter { $0.name.namespace == "intellij.vfs" }
        XCTAssertEqual(apis.count, 3)
    }

    func testFileEditorAPICountIs3() {
        let surface = registry.registerSurface()
        let apis = surface.apis.filter { $0.name.namespace == "intellij.fileEditor" }
        XCTAssertEqual(apis.count, 3)
    }

    func testActionAPICountIs2() {
        let surface = registry.registerSurface()
        let apis = surface.apis.filter { $0.name.namespace == "intellij.action" }
        XCTAssertEqual(apis.count, 2)
    }

    func testApplicationAPICountIs2() {
        let surface = registry.registerSurface()
        let apis = surface.apis.filter { $0.name.namespace == "intellij.application" }
        XCTAssertEqual(apis.count, 2)
    }

    func testMessagesAPICountIs4() {
        let surface = registry.registerSurface()
        let apis = surface.apis.filter { $0.name.namespace == "intellij.messages" }
        XCTAssertEqual(apis.count, 4)
    }

    func testRunManagerAPICountIs2() {
        let surface = registry.registerSurface()
        let apis = surface.apis.filter { $0.name.namespace == "intellij.runManager" }
        XCTAssertEqual(apis.count, 2)
    }

    func testPsiAPICountIs3() {
        let surface = registry.registerSurface()
        let apis = surface.apis.filter { $0.name.namespace == "intellij.psi" }
        XCTAssertEqual(apis.count, 3)
    }

    // MARK: - Internal API Detection

    func testInternalAPIRejection() {
        XCTAssertTrue(registry.isInternalAPI("com.intellij.psi.impl.PsiElementImpl"))
        XCTAssertTrue(registry.isInternalAPI("com.intellij.openapi.application.impl.ApplicationImpl"))
        XCTAssertTrue(registry.isInternalAPI("com.intellij.util.messages.impl.MessageBusImpl"))
    }

    func testPublicAPINotRejected() {
        XCTAssertFalse(registry.isInternalAPI("com.intellij.psi.PsiElement"))
        XCTAssertFalse(registry.isInternalAPI("com.intellij.openapi.project.Project"))
        XCTAssertFalse(registry.isInternalAPI("com.intellij.openapi.editor.Editor"))
    }

    func testDegradationStrategyForInternalAPI() {
        let api = APIName(namespace: "com.intellij.psi.impl", method: "PsiElementImpl")
        let strategy = registry.degradationStrategy(for: api)
        XCTAssertEqual(strategy, .disable)
    }

    func testDegradationStrategyForRegisteredAPI() {
        let api = APIName(namespace: "intellij.project", method: "getBaseDir")
        let strategy = registry.degradationStrategy(for: api)
        XCTAssertEqual(strategy, .shim)
    }

    func testDegradationStrategyForUnknownAPI() {
        let api = APIName(namespace: "intellij.unknown", method: "unknown")
        let strategy = registry.degradationStrategy(for: api)
        XCTAssertEqual(strategy, .promptOnly)
    }

    // MARK: - UI RPC Verification (REQ-020)

    func testUIRPCRequiredForActionAndMessages() {
        let actionAPI = APIName(namespace: "intellij.action", method: "actionPerformed")
        let messagesAPI = APIName(namespace: "intellij.messages", method: "showInfoMessage")
        let actionMapping = registry.resolveOpenAPI(actionAPI)
        let messagesMapping = registry.resolveOpenAPI(messagesAPI)
        XCTAssertTrue(actionMapping!.requiresUIRPC, "Action operations must require UI RPC (REQ-020)")
        XCTAssertTrue(messagesMapping!.requiresUIRPC, "Message operations must require UI RPC (REQ-020)")
    }

    func testUIRPCNotRequiredForReadOperations() {
        let projectAPI = APIName(namespace: "intellij.project", method: "getBaseDir")
        let editorAPI = APIName(namespace: "intellij.editor", method: "getText")
        let vfsAPI = APIName(namespace: "intellij.vfs", method: "getContents")
        let psiAPI = APIName(namespace: "intellij.psi", method: "getChildren")
        XCTAssertFalse(registry.resolveOpenAPI(projectAPI)!.requiresUIRPC)
        XCTAssertFalse(registry.resolveOpenAPI(editorAPI)!.requiresUIRPC)
        XCTAssertFalse(registry.resolveOpenAPI(vfsAPI)!.requiresUIRPC)
        XCTAssertFalse(registry.resolveOpenAPI(psiAPI)!.requiresUIRPC)
    }
}
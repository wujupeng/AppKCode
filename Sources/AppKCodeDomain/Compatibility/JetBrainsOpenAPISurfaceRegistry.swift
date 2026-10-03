import Foundation
import AppKCodeShared

// MARK: - JetBrains OpenAPI Mapping (TASK-020.4)

public struct JetBrainsOpenAPIMapping: Sendable, Codable, Hashable {
    public let openAPI: APIName
    public let nativeService: String
    public let isReadOnly: Bool
    public let requiresUIRPC: Bool
    public let rpcMethod: String

    public init(
        openAPI: APIName,
        nativeService: String,
        isReadOnly: Bool,
        requiresUIRPC: Bool,
        rpcMethod: String
    ) {
        self.openAPI = openAPI
        self.nativeService = nativeService
        self.isReadOnly = isReadOnly
        self.requiresUIRPC = requiresUIRPC
        self.rpcMethod = rpcMethod
    }
}

// MARK: - JetBrains OpenAPI Surface Registry Protocol (TASK-020.1)

public protocol JetBrainsOpenAPISurfaceRegistry: Sendable {
    func registerSurface() -> PublicProtocolSurface
    func registerContracts(in registry: CapabilityContractRegistry) async throws
    func resolveOpenAPI(_ name: APIName) -> JetBrainsOpenAPIMapping?
    func degradationStrategy(for api: APIName) -> DegradationStrategy
    func isInternalAPI(_ className: String) -> Bool
}

// MARK: - JetBrains OpenAPI Surface Registry Impl (TASK-020.2~020.6, H21, H26)

public final class JetBrainsOpenAPISurfaceRegistryImpl: JetBrainsOpenAPISurfaceRegistry, @unchecked Sendable {

    private static let pluginHostVersion = SemVer(1, 0, 0)

    private static let readOnlyPermission = ExtensionPermission(
        scope: .filesystem(path: "*", access: .readOnly),
        operations: [.read],
        riskLevel: .readOnly,
        requiresApproval: false
    )

    private static let readWritePermission = ExtensionPermission(
        scope: .filesystem(path: "*", access: .readWrite),
        operations: [.read, .write],
        riskLevel: .high,
        requiresApproval: true
    )

    private static let uiPermission = ExtensionPermission(
        scope: .ui,
        operations: [.read, .write],
        riskLevel: .low,
        requiresApproval: false
    )

    private static let uiSensitivePermission = ExtensionPermission(
        scope: .ui,
        operations: [.read, .write],
        riskLevel: .high,
        requiresApproval: true
    )

    private static let actionPermission = ExtensionPermission(
        scope: .process(command: "*"),
        operations: [.execute],
        riskLevel: .high,
        requiresApproval: true
    )

    private static let applicationPermission = ExtensionPermission(
        scope: .environment(variables: []),
        operations: [.read, .write],
        riskLevel: .low,
        requiresApproval: false
    )

    private static let runPermission = ExtensionPermission(
        scope: .process(command: "*"),
        operations: [.execute],
        riskLevel: .high,
        requiresApproval: true
    )

    // MARK: OpenAPI Definitions — 9 interfaces

    private static let projectAPIs: [(APIName, String, Bool, Bool, String, ExtensionPermission)] = [
        (APIName(namespace: "intellij.project", method: "getBaseDir"), "WorkspaceService.getBaseDir", true, false, "project.getBaseDir", readOnlyPermission),
        (APIName(namespace: "intellij.project", method: "getProjectDir"), "WorkspaceService.getProjectDir", true, false, "project.getProjectDir", readOnlyPermission)
    ]

    private static let editorAPIs: [(APIName, String, Bool, Bool, String, ExtensionPermission)] = [
        (APIName(namespace: "intellij.editor", method: "getText"), "TextEditorService.getText", true, false, "editor.getText", readOnlyPermission),
        (APIName(namespace: "intellij.editor", method: "getCaretModel"), "TextEditorService.getCaretModel", true, false, "editor.getCaretModel", readOnlyPermission),
        (APIName(namespace: "intellij.editor", method: "getSelectionModel"), "TextEditorService.getSelectionModel", true, false, "editor.getSelectionModel", readOnlyPermission)
    ]

    private static let vfsAPIs: [(APIName, String, Bool, Bool, String, ExtensionPermission)] = [
        (APIName(namespace: "intellij.vfs", method: "getPath"), "FileSystemService.getPath", true, false, "vfs.getPath", readOnlyPermission),
        (APIName(namespace: "intellij.vfs", method: "getContents"), "FileSystemService.getContents", true, false, "vfs.getContents", readOnlyPermission),
        (APIName(namespace: "intellij.vfs", method: "exists"), "FileSystemService.exists", true, false, "vfs.exists", readOnlyPermission)
    ]

    private static let fileEditorAPIs: [(APIName, String, Bool, Bool, String, ExtensionPermission)] = [
        (APIName(namespace: "intellij.fileEditor", method: "openFile"), "EditorManagerService.openFile", false, false, "fileEditor.openFile", readWritePermission),
        (APIName(namespace: "intellij.fileEditor", method: "closeFile"), "EditorManagerService.closeFile", false, false, "fileEditor.closeFile", readWritePermission),
        (APIName(namespace: "intellij.fileEditor", method: "getSelectedFiles"), "EditorManagerService.getSelectedFiles", true, false, "fileEditor.getSelectedFiles", readOnlyPermission)
    ]

    private static let actionAPIs: [(APIName, String, Bool, Bool, String, ExtensionPermission)] = [
        (APIName(namespace: "intellij.action", method: "registerAction"), "ActionRegistry.register", false, true, "action.registerAction", actionPermission),
        (APIName(namespace: "intellij.action", method: "actionPerformed"), "ActionRegistry.perform", false, true, "action.actionPerformed", actionPermission)
    ]

    private static let applicationAPIs: [(APIName, String, Bool, Bool, String, ExtensionPermission)] = [
        (APIName(namespace: "intellij.application", method: "invokeLater"), "ApplicationService.invokeLater", false, false, "application.invokeLater", applicationPermission),
        (APIName(namespace: "intellij.application", method: "isDisposed"), "ApplicationService.isDisposed", true, false, "application.isDisposed", readOnlyPermission)
    ]

    private static let messagesAPIs: [(APIName, String, Bool, Bool, String, ExtensionPermission)] = [
        (APIName(namespace: "intellij.messages", method: "showInfoMessage"), "UIService.showInfoMessage", false, true, "ui.showInfoMessage", uiPermission),
        (APIName(namespace: "intellij.messages", method: "showInputDialog"), "UIService.showInputDialog", false, true, "ui.showInputDialog", uiSensitivePermission),
        (APIName(namespace: "intellij.messages", method: "showChooseDialog"), "UIService.showChooseDialog", false, true, "ui.showChooseDialog", uiPermission),
        (APIName(namespace: "intellij.messages", method: "showOkCancelDialog"), "UIService.showOkCancelDialog", false, true, "ui.showOkCancelDialog", uiPermission)
    ]

    private static let runManagerAPIs: [(APIName, String, Bool, Bool, String, ExtensionPermission)] = [
        (APIName(namespace: "intellij.runManager", method: "getRunConfigurations"), "BuildRunService.getRunConfigurations", true, false, "runManager.getRunConfigurations", readOnlyPermission),
        (APIName(namespace: "intellij.runManager", method: "createConfiguration"), "BuildRunService.createConfiguration", false, false, "runManager.createConfiguration", runPermission)
    ]

    private static let psiAPIs: [(APIName, String, Bool, Bool, String, ExtensionPermission)] = [
        (APIName(namespace: "intellij.psi", method: "getChildren"), "ASTService.getChildren", true, false, "psi.getChildren", readOnlyPermission),
        (APIName(namespace: "intellij.psi", method: "getText"), "ASTService.getText", true, false, "psi.getText", readOnlyPermission),
        (APIName(namespace: "intellij.psi", method: "getContainingFile"), "ASTService.getContainingFile", true, false, "psi.getContainingFile", readOnlyPermission)
    ]

    private static let allAPITuples: [(APIName, String, Bool, Bool, String, ExtensionPermission)] =
        projectAPIs + editorAPIs + vfsAPIs + fileEditorAPIs + actionAPIs + applicationAPIs + messagesAPIs + runManagerAPIs + psiAPIs

    private static let internalAPIPatterns: [String] = [
        "com.intellij.psi.impl.",
        "com.intellij.openapi.application.impl.",
        "com.intellij.util.messages.impl."
    ]

    private static let promptOnlyAPIs: Set<String> = [
        "intellij.debug.startDebugging"
    ]

    // MARK: Mappings

    private lazy var mappings: [APIName: JetBrainsOpenAPIMapping] = {
        var map: [APIName: JetBrainsOpenAPIMapping] = [:]
        for tuple in Self.allAPITuples {
            map[tuple.0] = JetBrainsOpenAPIMapping(
                openAPI: tuple.0,
                nativeService: tuple.1,
                isReadOnly: tuple.2,
                requiresUIRPC: tuple.3,
                rpcMethod: tuple.4
            )
        }
        return map
    }()

    private lazy var apiToPermission: [APIName: ExtensionPermission] = {
        var map: [APIName: ExtensionPermission] = [:]
        for tuple in Self.allAPITuples {
            map[tuple.0] = tuple.5
        }
        return map
    }()

    // MARK: Init

    public init() {}

    // MARK: TASK-020.2: registerSurface

    public func registerSurface() -> PublicProtocolSurface {
        let apis = Self.allAPITuples.map { tuple -> PublicAPI in
            PublicAPI(
                name: tuple.0,
                signature: "\(tuple.0.namespace).\(tuple.0.method)() -> \(tuple.1)",
                permission: tuple.5,
                since: Self.pluginHostVersion
            )
        }
        return PublicProtocolSurface(
            apis: apis,
            version: Self.pluginHostVersion,
            deprecated: []
        )
    }

    // MARK: TASK-020.3: registerContracts

    public func registerContracts(in registry: CapabilityContractRegistry) async throws {
        try await registerGroupContract(
            name: "jetbrains.project",
            apis: Self.projectAPIs.map { $0.0 },
            permission: Self.readOnlyPermission,
            in: registry
        )
        try await registerGroupContract(
            name: "jetbrains.editor",
            apis: Self.editorAPIs.map { $0.0 },
            permission: Self.readOnlyPermission,
            in: registry
        )
        try await registerGroupContract(
            name: "jetbrains.vfs",
            apis: Self.vfsAPIs.map { $0.0 },
            permission: Self.readOnlyPermission,
            in: registry
        )
        try await registerGroupContract(
            name: "jetbrains.fileEditor",
            apis: Self.fileEditorAPIs.map { $0.0 },
            permission: Self.readWritePermission,
            in: registry
        )
        try await registerGroupContract(
            name: "jetbrains.action",
            apis: Self.actionAPIs.map { $0.0 },
            permission: Self.actionPermission,
            in: registry
        )
        try await registerGroupContract(
            name: "jetbrains.application",
            apis: Self.applicationAPIs.map { $0.0 },
            permission: Self.applicationPermission,
            in: registry
        )
        try await registerGroupContract(
            name: "jetbrains.messages",
            apis: Self.messagesAPIs.map { $0.0 },
            permission: Self.uiPermission,
            in: registry
        )
        try await registerGroupContract(
            name: "jetbrains.runManager",
            apis: Self.runManagerAPIs.map { $0.0 },
            permission: Self.runPermission,
            in: registry
        )
        try await registerGroupContract(
            name: "jetbrains.psi",
            apis: Self.psiAPIs.map { $0.0 },
            permission: Self.readOnlyPermission,
            in: registry
        )
    }

    private func registerGroupContract(
        name: String,
        apis: [APIName],
        permission: ExtensionPermission,
        in registry: CapabilityContractRegistry
    ) async throws {
        let inputSchema = JSONSchema(
            type: "object",
            properties: [
                "method": JSONSchemaProperty(type: "string", description: "JetBrains OpenAPI method name"),
                "args": JSONSchemaProperty(type: "array", description: "API arguments")
            ],
            required: ["method"],
            description: "JetBrains OpenAPI invocation input"
        )
        let outputSchema = JSONSchema(
            type: "object",
            properties: [
                "success": JSONSchemaProperty(type: "boolean", description: "Operation success flag"),
                "result": JSONSchemaProperty(type: "object", description: "Operation result data")
            ],
            required: ["success"],
            description: "JetBrains OpenAPI invocation output"
        )
        let contract = CapabilityContract(
            id: CapabilityContractID(),
            name: name,
            protocolKind: .jetbrains,
            supportedAPIs: apis,
            degradationStrategy: .shim,
            testCases: [TestCaseID()],
            inputSchema: inputSchema,
            outputSchema: outputSchema,
            requiredPermission: permission,
            minHostVersion: Self.pluginHostVersion,
            maxHostVersion: nil
        )
        _ = try await registry.register(contract)
    }

    // MARK: TASK-020.5: resolveOpenAPI

    public func resolveOpenAPI(_ name: APIName) -> JetBrainsOpenAPIMapping? {
        return mappings[name]
    }

    // MARK: TASK-020.6: isInternalAPI

    public func isInternalAPI(_ className: String) -> Bool {
        for pattern in Self.internalAPIPatterns {
            if className.hasPrefix(pattern) {
                return true
            }
        }
        return false
    }

    // MARK: Degradation Strategy

    public func degradationStrategy(for api: APIName) -> DegradationStrategy {
        let fullKey = "\(api.namespace).\(api.method)"

        if Self.promptOnlyAPIs.contains(fullKey) {
            return .promptOnly
        }

        if isInternalAPI(fullKey) {
            return .disable
        }

        if mappings[api] != nil {
            return .shim
        }

        return .promptOnly
    }

    // MARK: Utility

    public var allSupportedAPIs: [APIName] {
        return Self.allAPITuples.map { $0.0 }
    }

    public var apiCount: Int {
        return Self.allAPITuples.count
    }

    public var openAPIInterfaceCount: Int {
        return 9
    }

    public func readOnlyAPIs() -> [APIName] {
        return Self.allAPITuples.filter { $0.2 }.map { $0.0 }
    }

    public func uiRPCAPIs() -> [APIName] {
        return Self.allAPITuples.filter { $0.3 }.map { $0.0 }
    }
}
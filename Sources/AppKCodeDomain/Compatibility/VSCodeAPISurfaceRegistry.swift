import Foundation
import AppKCodeShared

// MARK: - VS Code API Mapping (TASK-011.4)

public struct VSCodeAPIMapping: Sendable, Codable, Hashable {
    public let api: APIName
    public let nativeService: String
    public let requiresAuthorization: Bool
    public let riskLevel: PermissionRiskLevel
    public let ipcMethod: String

    public init(
        api: APIName,
        nativeService: String,
        requiresAuthorization: Bool,
        riskLevel: PermissionRiskLevel,
        ipcMethod: String
    ) {
        self.api = api
        self.nativeService = nativeService
        self.requiresAuthorization = requiresAuthorization
        self.riskLevel = riskLevel
        self.ipcMethod = ipcMethod
    }
}

// MARK: - VS Code API Surface Registry Protocol (TASK-011.1)

public protocol VSCodeAPISurfaceRegistry: Sendable {
    func registerSurface() -> PublicProtocolSurface
    func registerContracts(in registry: CapabilityContractRegistry) async throws
    func resolveAPI(_ name: APIName) -> VSCodeAPIMapping?
    func degradationStrategy(for api: APIName) -> DegradationStrategy
}

// MARK: - VS Code API Surface Registry Impl (TASK-011.2~011.6, H21, H26)

public final class VSCodeAPISurfaceRegistryImpl: VSCodeAPISurfaceRegistry, @unchecked Sendable {

    private static let vscodeHostVersion = SemVer(1, 0, 0)

    private static let fsReadPermission = ExtensionPermission(
        scope: .filesystem(path: "*", access: .readOnly),
        operations: [.read],
        riskLevel: .readOnly,
        requiresApproval: false
    )

    private static let fsWritePermission = ExtensionPermission(
        scope: .filesystem(path: "*", access: .readWrite),
        operations: [.write, .read],
        riskLevel: .high,
        requiresApproval: true
    )

    private static let workspacePermission = ExtensionPermission(
        scope: .filesystem(path: "*", access: .readOnly),
        operations: [.read, .subscribe],
        riskLevel: .low,
        requiresApproval: false
    )

    private static let uiPermission = ExtensionPermission(
        scope: .ui,
        operations: [.read, .write],
        riskLevel: .low,
        requiresApproval: false
    )

    private static let uiTerminalPermission = ExtensionPermission(
        scope: .process(command: "*"),
        operations: [.execute],
        riskLevel: .high,
        requiresApproval: true
    )

    private static let commandPermission = ExtensionPermission(
        scope: .process(command: "*"),
        operations: [.execute],
        riskLevel: .high,
        requiresApproval: true
    )

    private static let languageProviderPermission = ExtensionPermission(
        scope: .filesystem(path: "*", access: .readOnly),
        operations: [.read, .subscribe],
        riskLevel: .low,
        requiresApproval: false
    )

    private static let extensionLookupPermission = ExtensionPermission(
        scope: .filesystem(path: "*", access: .readOnly),
        operations: [.read],
        riskLevel: .readOnly,
        requiresApproval: false
    )

    private static let envPermission = ExtensionPermission(
        scope: .environment(variables: []),
        operations: [.read, .write],
        riskLevel: .low,
        requiresApproval: false
    )

    private static let taskPermission = ExtensionPermission(
        scope: .process(command: "*"),
        operations: [.execute],
        riskLevel: .high,
        requiresApproval: true
    )

    // MARK: API Definitions

    private static let fsAPIs: [(APIName, String, Bool, PermissionRiskLevel, String, ExtensionPermission)] = [
        (APIName(namespace: "workspace.fs", method: "readFile"), "FileSystemService.read", false, .readOnly, "fs.readFile", fsReadPermission),
        (APIName(namespace: "workspace.fs", method: "writeFile"), "FileSystemService.write", true, .high, "fs.writeFile", fsWritePermission),
        (APIName(namespace: "workspace.fs", method: "readdir"), "FileSystemService.readdir", false, .readOnly, "fs.readdir", fsReadPermission),
        (APIName(namespace: "workspace.fs", method: "delete"), "FileSystemService.delete", true, .high, "fs.delete", fsWritePermission),
        (APIName(namespace: "workspace.fs", method: "rename"), "FileSystemService.rename", true, .high, "fs.rename", fsWritePermission),
        (APIName(namespace: "workspace.fs", method: "copy"), "FileSystemService.copy", true, .high, "fs.copy", fsWritePermission),
        (APIName(namespace: "workspace.fs", method: "stat"), "FileSystemService.stat", false, .readOnly, "fs.stat", fsReadPermission),
        (APIName(namespace: "workspace.fs", method: "createDirectory"), "FileSystemService.mkdir", true, .high, "fs.createDirectory", fsWritePermission)
    ]

    private static let workspaceAPIs: [(APIName, String, Bool, PermissionRiskLevel, String, ExtensionPermission)] = [
        (APIName(namespace: "workspace", method: "workspaceFolders"), "WorkspaceService.workspaceFolders", false, .readOnly, "workspace.workspaceFolders", workspacePermission),
        (APIName(namespace: "workspace", method: "getConfiguration"), "ConfigurationService.get", false, .readOnly, "workspace.getConfiguration", workspacePermission),
        (APIName(namespace: "workspace", method: "onDidChangeConfiguration"), "ConfigurationService.subscribe", false, .low, "workspace.onDidChangeConfiguration", workspacePermission),
        (APIName(namespace: "workspace", method: "findFiles"), "WorkspaceService.findFiles", false, .readOnly, "workspace.findFiles", workspacePermission),
        (APIName(namespace: "workspace", method: "openTextDocument"), "WorkspaceService.openTextDocument", false, .low, "workspace.openTextDocument", workspacePermission),
        (APIName(namespace: "workspace", method: "saveAll"), "WorkspaceService.saveAll", true, .high, "workspace.saveAll", fsWritePermission)
    ]

    private static let windowAPIs: [(APIName, String, Bool, PermissionRiskLevel, String, ExtensionPermission)] = [
        (APIName(namespace: "window", method: "showInformationMessage"), "PresentationService.showInformationMessage", false, .low, "window.showInformationMessage", uiPermission),
        (APIName(namespace: "window", method: "showErrorMessage"), "PresentationService.showErrorMessage", false, .low, "window.showErrorMessage", uiPermission),
        (APIName(namespace: "window", method: "showWarningMessage"), "PresentationService.showWarningMessage", false, .low, "window.showWarningMessage", uiPermission),
        (APIName(namespace: "window", method: "showInputBox"), "PresentationService.showInputBox", false, .low, "window.showInputBox", uiPermission),
        (APIName(namespace: "window", method: "showQuickPick"), "PresentationService.showQuickPick", false, .low, "window.showQuickPick", uiPermission),
        (APIName(namespace: "window", method: "createOutputChannel"), "PresentationService.createOutputChannel", false, .low, "window.createOutputChannel", uiPermission),
        (APIName(namespace: "window", method: "createTerminal"), "PresentationService.createTerminal", true, .high, "window.createTerminal", uiTerminalPermission),
        (APIName(namespace: "window", method: "activeTextEditor"), "PresentationService.activeTextEditor", false, .readOnly, "window.activeTextEditor", uiPermission),
        (APIName(namespace: "window", method: "showTextDocument"), "PresentationService.showTextDocument", false, .low, "window.showTextDocument", uiPermission)
    ]

    private static let commandsAPIs: [(APIName, String, Bool, PermissionRiskLevel, String, ExtensionPermission)] = [
        (APIName(namespace: "commands", method: "executeCommand"), "CommandRegistry.execute", true, .high, "commands.executeCommand", commandPermission),
        (APIName(namespace: "commands", method: "registerCommand"), "CommandRegistry.register", false, .low, "commands.registerCommand", uiPermission)
    ]

    private static let languagesAPIs: [(APIName, String, Bool, PermissionRiskLevel, String, ExtensionPermission)] = [
        (APIName(namespace: "languages", method: "registerCompletionItemProvider"), "LSPService.registerCompletionProvider", false, .low, "languages.registerCompletionItemProvider", languageProviderPermission),
        (APIName(namespace: "languages", method: "registerHoverProvider"), "LSPService.registerHoverProvider", false, .low, "languages.registerHoverProvider", languageProviderPermission),
        (APIName(namespace: "languages", method: "registerDefinitionProvider"), "LSPService.registerDefinitionProvider", false, .low, "languages.registerDefinitionProvider", languageProviderPermission),
        (APIName(namespace: "languages", method: "registerCodeActionsProvider"), "LSPService.registerCodeActionsProvider", false, .low, "languages.registerCodeActionsProvider", languageProviderPermission),
        (APIName(namespace: "languages", method: "createDiagnosticCollection"), "LSPService.createDiagnosticCollection", false, .low, "languages.createDiagnosticCollection", languageProviderPermission)
    ]

    private static let extensionsAPIs: [(APIName, String, Bool, PermissionRiskLevel, String, ExtensionPermission)] = [
        (APIName(namespace: "extensions", method: "getExtension"), "ExtensionRegistry.getExtension", false, .readOnly, "extensions.getExtension", extensionLookupPermission),
        (APIName(namespace: "extensions", method: "onDidChangeExtensions"), "ExtensionRegistry.subscribe", false, .low, "extensions.onDidChangeExtensions", extensionLookupPermission)
    ]

    private static let envAPIs: [(APIName, String, Bool, PermissionRiskLevel, String, ExtensionPermission)] = [
        (APIName(namespace: "env", method: "openExternal"), "EnvironmentService.openExternal", false, .low, "env.openExternal", envPermission),
        (APIName(namespace: "env", method: "clipboard"), "EnvironmentService.clipboard", false, .low, "env.clipboard", envPermission)
    ]

    private static let tasksAPIs: [(APIName, String, Bool, PermissionRiskLevel, String, ExtensionPermission)] = [
        (APIName(namespace: "tasks", method: "executeTask"), "TaskService.executeTask", true, .high, "tasks.executeTask", taskPermission),
        (APIName(namespace: "tasks", method: "registerTaskProvider"), "TaskService.registerTaskProvider", false, .low, "tasks.registerTaskProvider", taskPermission)
    ]

    private static let allAPITuples: [(APIName, String, Bool, PermissionRiskLevel, String, ExtensionPermission)] =
        fsAPIs + workspaceAPIs + windowAPIs + commandsAPIs + languagesAPIs + extensionsAPIs + envAPIs + tasksAPIs

    private static let proposedAPINamespaces: Set<String> = [
        "vscode.proposed"
    ]

    private static let promptOnlyAPIs: Set<String> = [
        "debug.startDebugging"
    ]

    // MARK: Mappings

    private lazy var mappings: [APIName: VSCodeAPIMapping] = {
        var map: [APIName: VSCodeAPIMapping] = [:]
        for tuple in Self.allAPITuples {
            map[tuple.0] = VSCodeAPIMapping(
                api: tuple.0,
                nativeService: tuple.1,
                requiresAuthorization: tuple.2,
                riskLevel: tuple.3,
                ipcMethod: tuple.4
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

    // MARK: TASK-011.2: registerSurface

    public func registerSurface() -> PublicProtocolSurface {
        let apis = Self.allAPITuples.map { tuple -> PublicAPI in
            PublicAPI(
                name: tuple.0,
                signature: "\(tuple.0.namespace).\(tuple.0.method)() -> \(tuple.1)",
                permission: tuple.5,
                since: Self.vscodeHostVersion
            )
        }
        return PublicProtocolSurface(
            apis: apis,
            version: Self.vscodeHostVersion,
            deprecated: []
        )
    }

    // MARK: TASK-011.3: registerContracts

    public func registerContracts(in registry: CapabilityContractRegistry) async throws {
        try await registerGroupContract(
            name: "vscode.workspace.fs",
            apis: Self.fsAPIs.map { $0.0 },
            permission: Self.fsWritePermission,
            in: registry
        )
        try await registerGroupContract(
            name: "vscode.workspace",
            apis: Self.workspaceAPIs.map { $0.0 },
            permission: Self.workspacePermission,
            in: registry
        )
        try await registerGroupContract(
            name: "vscode.window",
            apis: Self.windowAPIs.map { $0.0 },
            permission: Self.uiPermission,
            in: registry
        )
        try await registerGroupContract(
            name: "vscode.commands",
            apis: Self.commandsAPIs.map { $0.0 },
            permission: Self.commandPermission,
            in: registry
        )
        try await registerGroupContract(
            name: "vscode.languages",
            apis: Self.languagesAPIs.map { $0.0 },
            permission: Self.languageProviderPermission,
            in: registry
        )
        try await registerGroupContract(
            name: "vscode.extensions",
            apis: Self.extensionsAPIs.map { $0.0 },
            permission: Self.extensionLookupPermission,
            in: registry
        )
        try await registerGroupContract(
            name: "vscode.env",
            apis: Self.envAPIs.map { $0.0 },
            permission: Self.envPermission,
            in: registry
        )
        try await registerGroupContract(
            name: "vscode.tasks",
            apis: Self.tasksAPIs.map { $0.0 },
            permission: Self.taskPermission,
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
                "method": JSONSchemaProperty(type: "string", description: "VS Code API method name"),
                "args": JSONSchemaProperty(type: "array", description: "API arguments")
            ],
            required: ["method"],
            description: "VS Code API invocation input"
        )
        let outputSchema = JSONSchema(
            type: "object",
            properties: [
                "success": JSONSchemaProperty(type: "boolean", description: "Operation success flag"),
                "result": JSONSchemaProperty(type: "object", description: "Operation result data")
            ],
            required: ["success"],
            description: "VS Code API invocation output"
        )
        let contract = CapabilityContract(
            id: CapabilityContractID(),
            name: name,
            protocolKind: .vscode,
            supportedAPIs: apis,
            degradationStrategy: .shim,
            testCases: [TestCaseID()],
            inputSchema: inputSchema,
            outputSchema: outputSchema,
            requiredPermission: permission,
            minHostVersion: Self.vscodeHostVersion,
            maxHostVersion: nil
        )
        _ = try await registry.register(contract)
    }

    // MARK: TASK-011.5: resolveAPI

    public func resolveAPI(_ name: APIName) -> VSCodeAPIMapping? {
        return mappings[name]
    }

    // MARK: TASK-011.6: degradationStrategy

    public func degradationStrategy(for api: APIName) -> DegradationStrategy {
        let fullKey = "\(api.namespace).\(api.method)"

        if Self.proposedAPINamespaces.contains(api.namespace) {
            return .disable
        }

        if Self.promptOnlyAPIs.contains(fullKey) {
            return .promptOnly
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
}
import Foundation

// MARK: - Extension Host Type (TASK-002.1)

public enum ExtensionHostType: String, Sendable, Codable, Hashable {
    case vscodeExtensionHost
    case jetbrainsPluginHost
}

// MARK: - Host Process State (TASK-002.2)

public enum HostProcessState: Sendable, Codable, Hashable, Equatable {
    case notStarted
    case starting
    case running(pid: ProcessID)
    case crashed(exitCode: Int32, timestamp: ISO8601Timestamp)
    case restarting
    case stopped(exitCode: Int32)
    case unstable(reason: String)
}

// MARK: - Process ID (TASK-002.5)

public struct ProcessID: Hashable, Sendable, Codable {
    public let value: Int32

    public init(_ value: Int32) {
        self.value = value
    }
}

// MARK: - Process Signal (TASK-002.5)

public enum ProcessSignal: Sendable, Codable, Hashable {
    case terminate
    case kill
    case interrupt
}

// MARK: - Extension Host Config (TASK-002.3)

public struct ExtensionHostConfig: Sendable, Codable, Equatable {
    public let hostType: ExtensionHostType
    public let runtimePath: String
    public let runtimeVersion: SemVer
    public let memoryLimitMB: Int
    public let cpuLimitPercent: Int
    public let ipcChannel: IPCChannelDescriptor
    public let hostScriptPath: String
    public let extraArgs: [String]

    public init(
        hostType: ExtensionHostType,
        runtimePath: String,
        runtimeVersion: SemVer,
        memoryLimitMB: Int,
        cpuLimitPercent: Int,
        ipcChannel: IPCChannelDescriptor,
        hostScriptPath: String,
        extraArgs: [String] = []
    ) {
        self.hostType = hostType
        self.runtimePath = runtimePath
        self.runtimeVersion = runtimeVersion
        self.memoryLimitMB = memoryLimitMB
        self.cpuLimitPercent = cpuLimitPercent
        self.ipcChannel = ipcChannel
        self.hostScriptPath = hostScriptPath
        self.extraArgs = extraArgs
    }
}

// MARK: - Host Process Handle (TASK-002.4)

public struct HostProcessHandle: Sendable, Codable, Equatable {
    public let processID: ProcessID
    public let ipcChannel: IPCChannelDescriptor
    public let startedAt: ISO8601Timestamp

    public init(processID: ProcessID, ipcChannel: IPCChannelDescriptor, startedAt: ISO8601Timestamp = ISO8601Timestamp()) {
        self.processID = processID
        self.ipcChannel = ipcChannel
        self.startedAt = startedAt
    }
}

// MARK: - Process Exit Info (TASK-002.4)

public struct ProcessExitInfo: Sendable, Codable, Equatable {
    public let exitCode: Int32
    public let timestamp: ISO8601Timestamp

    public init(exitCode: Int32, timestamp: ISO8601Timestamp = ISO8601Timestamp()) {
        self.exitCode = exitCode
        self.timestamp = timestamp
    }
}

// MARK: - Extension Host Error (TASK-002.6)

public enum ExtensionHostError: Error, Sendable, Codable, Hashable {
    case runtimeNotFound
    case startupTimeout
    case architectureMismatch(expected: String, actual: String)
    case ipcChannelFailed
    case hostCrashed(exitCode: Int32)
    case resourceLimitExceeded
}

// MARK: - VS Code Extension Manifest (TASK-004.1, REQ-042, spec §6.2)

public struct VSCodeExtensionManifest: Sendable, Codable, Equatable {
    public let extensionID: String
    public let version: SemVer
    public let enginesVSCode: String
    public let activationEvents: [String]
    public let mainEntry: String
    public let contributes: VSCodeContributes
    public let apiSurface: APISurface
    public let architectures: [Architecture]
    public let compatibilityContractID: CapabilityContractID

    public init(
        extensionID: String,
        version: SemVer,
        enginesVSCode: String,
        activationEvents: [String],
        mainEntry: String,
        contributes: VSCodeContributes,
        apiSurface: APISurface = .vscode,
        architectures: [Architecture] = [.x86_64],
        compatibilityContractID: CapabilityContractID = CapabilityContractID()
    ) {
        self.extensionID = extensionID
        self.version = version
        self.enginesVSCode = enginesVSCode
        self.activationEvents = activationEvents
        self.mainEntry = mainEntry
        self.contributes = contributes
        self.apiSurface = apiSurface
        self.architectures = architectures
        self.compatibilityContractID = compatibilityContractID
    }
}

// MARK: - VS Code Contributes (TASK-004.2)

public struct VSCodeContributes: Sendable, Codable, Equatable {
    public let commands: [String]
    public let configuration: [String]
    public let languages: [String]
    public let snippets: [String]

    public init(
        commands: [String] = [],
        configuration: [String] = [],
        languages: [String] = [],
        snippets: [String] = []
    ) {
        self.commands = commands
        self.configuration = configuration
        self.languages = languages
        self.snippets = snippets
    }
}

// MARK: - JetBrains Plugin Manifest (TASK-004.3, REQ-043, spec §6.3)

public struct JetBrainsPluginManifest: Sendable, Codable, Equatable {
    public let pluginID: String
    public let version: SemVer
    public let sinceBuild: String
    public let untilBuild: String?
    public let extensionPoints: [JetBrainsExtensionPoint]
    public let actions: [JetBrainsActionDecl]
    public let mainJAR: String
    public let apiSurface: APISurface
    public let architectures: [Architecture]
    public let compatibilityContractID: CapabilityContractID

    public init(
        pluginID: String,
        version: SemVer,
        sinceBuild: String,
        untilBuild: String? = nil,
        extensionPoints: [JetBrainsExtensionPoint] = [],
        actions: [JetBrainsActionDecl] = [],
        mainJAR: String,
        apiSurface: APISurface = .jetbrains,
        architectures: [Architecture] = [.x86_64],
        compatibilityContractID: CapabilityContractID = CapabilityContractID()
    ) {
        self.pluginID = pluginID
        self.version = version
        self.sinceBuild = sinceBuild
        self.untilBuild = untilBuild
        self.extensionPoints = extensionPoints
        self.actions = actions
        self.mainJAR = mainJAR
        self.apiSurface = apiSurface
        self.architectures = architectures
        self.compatibilityContractID = compatibilityContractID
    }
}

// MARK: - JetBrains Extension Point (TASK-004.4)

public struct JetBrainsExtensionPoint: Sendable, Codable, Equatable {
    public let name: String
    public let interfaceClass: String
    public let implementationClass: String

    public init(name: String, interfaceClass: String, implementationClass: String) {
        self.name = name
        self.interfaceClass = interfaceClass
        self.implementationClass = implementationClass
    }
}

// MARK: - JetBrains Action Declaration (TASK-004.4)

public struct JetBrainsActionDecl: Sendable, Codable, Equatable {
    public let id: String
    public let className: String
    public let text: String?

    public init(id: String, className: String, text: String? = nil) {
        self.id = id
        self.className = className
        self.text = text
    }
}

// MARK: - Architecture Validation (TASK-004.5, REQ-045)

public enum ArchitectureValidation: Sendable, Codable, Equatable {
    case valid
    case arm64Only(module: String)
    case missing
}
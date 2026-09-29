import Foundation

// MARK: - Adapter ID (TASK-006.1)

public struct AdapterID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init() { self.rawValue = UUID().uuidString }
    public init(_ value: String) { self.rawValue = value }
}

// MARK: - Adapter Kind (TASK-006.1)

public enum AdapterKind: Sendable, Codable, Hashable {
    case codearts
    case vscode
    case jetbrains
    case custom(String)
}

// MARK: - Adapter Descriptor (TASK-006.2)

public struct AdapterDescriptor: Sendable, Codable, Hashable {
    public let id: AdapterID
    public let kind: AdapterKind
    public let name: String
    public let supportedProtocol: ProtocolKind
    public let hostVersion: SemVer
    public let capabilities: [CapabilityID]

    public init(
        id: AdapterID,
        kind: AdapterKind,
        name: String,
        supportedProtocol: ProtocolKind,
        hostVersion: SemVer,
        capabilities: [CapabilityID] = []
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.supportedProtocol = supportedProtocol
        self.hostVersion = hostVersion
        self.capabilities = capabilities
    }
}

// MARK: - Adapter State (TASK-006.3)

public enum AdapterState: Sendable, Codable, Hashable, Equatable {
    case uninitialized
    case initialized
    case active
    case suspended
    case failed(reason: String)
    case disposed
}

// MARK: - Adapter Instantiation Context (TASK-006.4, H22)

public struct AdapterInstantiationContext: Sendable, Codable, Equatable {
    public let manifest: ExtensionManifest
    public let contract: CapabilityContract
    public let hostAPI: PublicProtocolSurface
    public let sessionID: AgentSessionID

    public init(
        manifest: ExtensionManifest,
        contract: CapabilityContract,
        hostAPI: PublicProtocolSurface,
        sessionID: AgentSessionID
    ) {
        self.manifest = manifest
        self.contract = contract
        self.hostAPI = hostAPI
        self.sessionID = sessionID
    }
}

// MARK: - Adapter Error (TASK-006.5, H22)

public enum AdapterError: Error, Sendable, Codable, Hashable {
    case unsupportedProtocol(ProtocolKind)
    case contractViolation(reason: String)
    case instantiationFailed(reason: String)
    case hostInternalAccess
    case apiNotSupported(APIName)
    case degraded(reason: String)
}